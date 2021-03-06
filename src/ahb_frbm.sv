// This confidential and proprietary software may be used only as
// authorised by a licensing agreement from The University of Southampton
// (c) COPYRIGHT 2010 The University of Southampton
// ALL RIGHTS RESERVED
// The entire notice above must be reproduced on all authorised
// copies and copies may only be made to the extent permitted
// by a licensing agreement from The University of Southampton.
//
// --------------------------------------------------------------------------
// Version and Release Control Information:
//
// File Name : ahb_frbm.v
// File Revision : 3.4, Kier Dugan (kjd1v07@ecs.soton.ac.uk)
//                      Matthew Swabey (mas@ecs.soton.ac.uk)
//                 3.5, Nick Plante (nplante@purdue.edu)
//                      Matthew Swabey (maswabey@purdue.edu)
//
// --------------------------------------------------------------------------
// Purpose : Generic AHB master that outputs signals based on the contesnts
//           of a command file.
// --------------------------------------------------------------------------

`timescale 1ns / 10ps

module ahb_frbm ( // File Reading Bus Master (FRBM)
    input  wire             HCLK,
    input  wire             HRESETn,
    output wire     [31:0]  HADDR,
    output wire     [ 2:0]  HBURST,
    output wire     [ 3:0]  HPROT,
    output wire     [ 2:0]  HSIZE,
    output wire     [ 1:0]  HTRANS,
    output wire     [31:0]  HWDATA,
    output wire             HWRITE,
    input  wire     [31:0]  HRDATA,
    input  wire             HREADY,
    input  wire     [ 1:0]  HRESP,
    output wire             HBUSREQ,
    output wire             HLOCK,
    input  wire             HGRANT
);

// Parameters and default values.
parameter MASTER_NAME   = "Master";
parameter TIC_CMD_FILE  = "../scripts/commands.tic";
parameter IDLE_WDATA    = 32'h0badbad0;    

// State names
localparam STATE_IDLE      = 3'b000;
localparam STATE_ADDR      = 3'b001;
localparam STATE_BUSY      = 3'b010;
localparam STATE_WRITE     = 3'b011;
localparam STATE_READ      = 3'b100;

// Transfer types
localparam TRANS_IDLE   = 2'b00;
localparam TRANS_BUSY   = 2'b01;
localparam TRANS_NONSEQ = 2'b10;
localparam TRANS_SEQ    = 2'b11;

// Burst signals
localparam BURST_SINGLE = 3'b000;
localparam BURST_INCR   = 3'b001;
localparam BURST_WRAP4  = 3'b010;
localparam BURST_INCR4  = 3'b011;
localparam BURST_WRAP8  = 3'b100;
localparam BURST_INCR8  = 3'b101;
localparam BURST_WRAP16 = 3'b110;
localparam BURST_INCR16 = 3'b111;

// AHB slave responses
localparam RESP_OKAY    = 2'b00;
localparam RESP_ERROR   = 2'b01;
localparam RESP_RETRY   = 2'b10;
localparam RESP_SPLIT   = 2'b11;

// AHB size coding
localparam HSIZE_32     = 3'b010;
localparam HSIZE_16     = 3'b001;
localparam HSIZE_8      = 3'b000;

// File reading variables.
integer         ticfr_fd;
integer         ticfr_status;
reg     [ 7:0]  ticfr_char;
reg     [31:0]  ticfr_data;

// Test controller signals
reg     [ 2:0]  tic_state;
reg             tic_term_pend;
reg             tic_error;
reg     [ 7:0]  tic_error_char;
reg             tic_aphase;
reg     [31:0]  tic_addr;
reg     [31:0]  tic_wdata;
reg     [31:0]  tic_edata;
reg     [31:0]  tic_edata_r;
reg     [31:0]  tic_mask ;
reg     [31:0]  tic_mask_r ;
reg     [31:0]  tic_cdata;
reg     [31:0]  tic_idle_cnt;
reg     [31:0]  tic_read_cnt;
reg     [31:0]  tic_write_cnt;
reg             tic_read;
reg             tic_read_r;
reg             tic_expect;
reg             tic_expect_r;
reg     [ 2:0]  tic_burst;
reg             tic_nonseq;
reg     [ 3:0]  tic_prot;
reg     [ 2:0]  tic_size;
reg             tic_write;
reg             tic_lock;

// AHB signals.
reg     [ 2:0]  ahb_burst;
reg     [ 3:0]  ahb_prot;
reg     [ 2:0]  ahb_size;
reg     [ 1:0]  ahb_trans;
reg             ahb_write;
reg             ahb_busreq;
reg             ahb_lock;
wire    [31:0]  ahb_rdata;
wire            ahb_ready;
wire    [ 1:0]  ahb_resp;
wire            ahb_grant;
reg     [31:0]  ahb_wdata;

// AHB registers.
reg     [31:0]  ahb_addr_r;
reg     [31:0]  ahb_addr_cur;
reg     [31:0]  ahb_rdata_r;
reg     [31:0]  ahb_wdata_r;

// Open the file
initial begin
    ticfr_fd = $fopen (TIC_CMD_FILE, "r");
    if (ticfr_fd == 0) begin
        $display ("%6dns %s: Failed to open command file %s for reading!",
            $time, MASTER_NAME, TIC_CMD_FILE);
        $stop; 
    end else begin
        $display ("%6dns %s: Loading command file %s.", $time, MASTER_NAME,
            TIC_CMD_FILE);
    end
end

// Determine if a command requires data to be read.
function ticfr_cmd_has_arg;
input [7:0] cmd;
begin
    case (cmd)
        "A", "C", "M", "W", "E", "B", "P", "L", "S": begin
            ticfr_cmd_has_arg = 1'b1;
        end

        default: begin
            ticfr_cmd_has_arg = 1'b0;
        end
    endcase
end
endfunction

// Some commands need to trigger another read of the file.
function ticfr_cmd_reread;
input [7:0] cmd;
begin
    case (cmd)
        "A", "P", "B", "L", "C", "M", "S", "#": begin
            ticfr_cmd_reread = 1'b1;
        end
        
        default: begin
            ticfr_cmd_reread = 1'b0;
        end
    endcase
end
endfunction

// Convert slave response codes into strings.
function [(5*8)-1 : 0] resp_as_string;
input [1:0] resp;
begin
    case (resp)
        RESP_OKAY:  resp_as_string = { "OKAY", 1'b0 };
        RESP_ERROR: resp_as_string = "ERROR";
        RESP_RETRY: resp_as_string = "RETRY";
        RESP_SPLIT: resp_as_string = "SPLIT";
    endcase
end
endfunction

// Local equivalent of C's "isspace"
function isspace;
input byte ch;
begin
    case (ch)
        8'h0D, 8'h0A, 8'h09, 8'h20: begin    // "\r", "\n", "\t", " "
            isspace = 1'b1;
        end
        
        default: begin
            isspace = 1'b0;
        end
    endcase
end
endfunction

// File reader loop.
task ticfr_read;
    tic_aphase <= 1'b0;
    do begin
        // Read a single character from the file.  We don't actually care about
        // the return value from fscanf, but putting it in a variable prevents
        // warnings.
        ticfr_status = $fscanf (ticfr_fd, "%c ", ticfr_char);
        
        // Read the argument.
        if (ticfr_cmd_has_arg (ticfr_char)) begin
            ticfr_status = $fscanf (ticfr_fd, "%h ", ticfr_data);
        end
        
        // Determine the command type.
        case (ticfr_char)
            "A": begin
                tic_addr        <= ticfr_data;
                tic_aphase      <= 1'b1;
                tic_nonseq <= '1;
            end

            "W": tic_wdata      <= ticfr_data;
            "E": tic_edata_r    <= ticfr_data;
            "M": tic_mask_r     <= ticfr_data;
            "C": tic_cdata      <= ticfr_data;
            "P": tic_prot       <= ticfr_data[3:0];
            "S": tic_size       <= ticfr_data[2:0];
            "B": begin
                tic_burst      <= ticfr_data[2:0];
                tic_nonseq <= '1;
            end
            "L": tic_lock       <= ticfr_data[0];
            
            "X": begin
                tic_term_pend   <= 1'b1;
                $fclose (ticfr_fd);
            end

            "#": begin
                int    i;
                string comment;
                
                // Eat the rest of the line up.
                ticfr_status = $fgets (comment, ticfr_fd);
                
                // Remove trailing whitespace.
                i = comment.len () - 1;
                while (isspace (comment.getc (i)))
                    --i;
                comment = comment.substr (0, i);
                
                // Print the comment text.
                $display ("%6dns %s comment: %s", $time, MASTER_NAME, comment);
            end

        endcase
        
        // Make sure that signals are latched during a busy cycle.
        if (ticfr_char != "U") begin
            // Save a pending write.
            tic_write       <= (ticfr_char == "W") ? 1'b1 : 1'b0;
            
            // Mark next read as a read.
            tic_read_r    <= (ticfr_char == "R") ? 1'b1 : 1'b0;
            // Mark next read as an expectation.
            tic_expect_r    <= (ticfr_char == "E") ? 1'b1 : 1'b0;
        end
        
        // Align expected signals correctly.
        tic_read <= tic_read_r;
        tic_expect <= tic_expect_r;
        tic_edata  <= tic_edata_r;
        tic_mask   <= tic_mask_r;
    end while (ticfr_cmd_reread (ticfr_char));
endtask

// State machine
always @ (posedge HCLK or negedge HRESETn) begin
    if (~HRESETn) begin
        // TIC signals
        tic_state       <= STATE_IDLE;
        tic_term_pend   <= '0;
        tic_addr        <= '0;
        tic_aphase      <= '0;
        tic_wdata       <= '0;
        tic_edata       <= '0;
        tic_edata_r     <= '0;
        tic_mask        <= '1;
        tic_mask_r      <= '1;
        tic_cdata       <= '0;
        tic_idle_cnt    <= '0;
        tic_read_cnt    <= '0;
        tic_write_cnt   <= '0;
        tic_read        <= '0;
        tic_read_r      <= '0;
        tic_expect      <= '0;
        tic_expect_r    <= '0;
        tic_burst       <= '0;
        tic_nonseq      <= '0;
        tic_prot        <= { 1'b0, 1'b0, 1'b1, 1'b1 };
        tic_size        <= HSIZE_32;
        tic_write       <= '0;
        tic_lock        <= '0;
        tic_error       <= '0;
        
        // AHB registers.
        ahb_addr_r      <= '0;
        ahb_addr_cur    <= '0;
        ahb_wdata_r     <= '0;
        ahb_rdata_r     <= '0;
    end else if (ahb_grant & ahb_ready & ~tic_term_pend) begin
        // Trigger a read cycle.
        ticfr_read;
            
        // Terminate current burst if an error occurred.
        if (tic_error) begin
            // Skip over remaining burst commands.
            while (ticfr_char == tic_error_char && ~tic_term_pend)
                ticfr_read;

            // Clear error status.
            tic_error <= 1'b0;
        end

        // Update counters.
        case (tic_state)
            STATE_IDLE: begin
                // Reset all counters.
                tic_idle_cnt    <= tic_idle_cnt + 1;
                tic_read_cnt    <= '0;
                tic_write_cnt   <= '0;
            end
            
            STATE_WRITE: begin
                // Reset read counter, increment write counter.
                tic_idle_cnt    <= '0;    
                tic_read_cnt    <= '0;
                if (tic_burst != BURST_SINGLE && tic_nonseq == 1) 
                    tic_nonseq <= '0;
                tic_write_cnt   <= tic_write_cnt + 1;
            end
            
            STATE_READ: begin
                // Reset write counter, increment read counter.
                tic_idle_cnt    <= '0;    
                if (tic_burst != BURST_SINGLE && tic_nonseq == 1)
                    tic_nonseq <= '0;
                tic_read_cnt   <= tic_read_cnt + 1;
                tic_write_cnt   <= '0;
            end
        endcase

        // Auto-increment the address.
        if (tic_aphase) begin
            case (tic_size) 
                HSIZE_32:   ahb_addr_r <= { (tic_addr[31:2] + 1), 2'b00 };
                HSIZE_16:   ahb_addr_r <= { (tic_addr[31:1] + 1), 1'b0 };
                HSIZE_8:    ahb_addr_r <= { (tic_addr[31:0] + 1) };
                default:    ahb_addr_r <= { (tic_addr[31:2] + 1), 2'b00 };
            endcase

        end else if (tic_state == STATE_WRITE || tic_state == STATE_READ) begin
            case (tic_size) 
                HSIZE_32:   ahb_addr_r <= { (ahb_addr_r[31:2] + 1), 2'b00 };
                HSIZE_16:   ahb_addr_r <= { (ahb_addr_r[31:1] + 1), 1'b0 };
                HSIZE_8:    ahb_addr_r <= { (ahb_addr_r[31:0] + 1) };
                default:    ahb_addr_r <= { (ahb_addr_r[31:2] + 1), 2'b00 };
            endcase
        end
        
        // Remember the address for the error messages.
        ahb_addr_cur <= { (tic_aphase ? tic_addr[31:2] : ahb_addr_r[31:2]), 2'b00 };

        // Decide next state.
        case (ticfr_char)
            "I", "X":   tic_state <= STATE_IDLE;
            "R", "E":   tic_state <= STATE_READ; 
            "W":        tic_state <= STATE_WRITE;
            "U":        tic_state <= STATE_BUSY;
            default: begin
                $display ("%6dns %s: Unknown state transition for %c, defaulting to IDLE.", $time, MASTER_NAME, ticfr_char);
                tic_state <= STATE_IDLE;
            end
        endcase
        
        // Delay read and write data by a clock cycle.
        ahb_wdata_r <= tic_wdata;
        ahb_rdata_r <= ahb_rdata;
       
        // Generate log messages - note this should be moved into a bus monitor for the future
        if (tic_read) begin
            //$display ("%6dns %s: Read 0x%08H from address 0x%08H.", $time, MASTER_NAME, ahb_rdata, ahb_addr_cur);
        end else if (tic_expect) begin
            if ((ahb_rdata & tic_mask) == tic_edata) begin
		/*
                $display ("%6dns %s: Successfully read 0x%08H from address 0x%08H.",
                    $time, MASTER_NAME, (ahb_rdata & tic_mask), ahb_addr_cur);
		*/
            end else begin
                $display ("%6dns %s: Expected 0x%08H from address 0x%08H, but read 0x%08H!",
                    $time, MASTER_NAME, tic_edata, ahb_addr_cur, (ahb_rdata & tic_mask));
            end
        end else if (ticfr_char == "X") begin
            $display ("%6dns %s: End of TIC command file.", $time, MASTER_NAME);
        end else begin
            case (tic_state)
                STATE_IDLE: begin
                    if (tic_idle_cnt == 0)
                        $display ("%6dns %s: Idle.", $time, MASTER_NAME);
                end
                
                STATE_WRITE: begin
                    $display ("%6dns %s: Writing 0x%08H to address 0x%08H.",
                        $time, MASTER_NAME, tic_wdata,
                        tic_aphase ? { tic_addr[31:2], 2'b00 } : ahb_addr_r);
                end
                
                STATE_BUSY: begin
                    $display ("%6dns %s: Busy.", $time, MASTER_NAME);
                end
            endcase
        end
    end else if (~ahb_ready & ahb_resp != RESP_OKAY) begin
        // Print a message stating the error, and skip over all remaining
        // commands of that type.
        tic_error       <= 1'b1;
        tic_state       <= STATE_IDLE;
        tic_error_char  <= ticfr_char;
        
        // Provide a detailed error message.
        case (tic_state)
            STATE_READ: begin
                $display ("%6dns %s: Slave at address 0x%08H responded with %s while attempting to read.",
                    $time, MASTER_NAME, HADDR, resp_as_string (ahb_resp));
            end
            
            STATE_WRITE: begin
                $display ("%6dns %s: Slave at address 0x%08H responded with %s while attempting to write 0x%08H.",
                    $time, MASTER_NAME, HADDR, resp_as_string (ahb_resp),
                    ahb_wdata_r);
            end
            
            default: begin
                $display ("%6dns %s: Slave at address 0x%08H responded with %s.",
                    $time, MASTER_NAME, HADDR, resp_as_string (ahb_resp));
            end
        endcase
    end
end

// Combinatorial output assignments
always @ (tic_state, tic_write_cnt, tic_read_cnt, tic_burst, tic_nonseq, tic_prot, tic_size,
          tic_lock, tic_write/*, ahb_wdata_r, tic_addr, ahb_addr_r */)
begin
    if (tic_state == STATE_IDLE) begin
        ahb_trans       = TRANS_IDLE;
        ahb_lock        = 1'b0;
        ahb_busreq      = 1'b0;
        ahb_write       = 1'b0;
        ahb_burst       = BURST_SINGLE;
        ahb_prot        = { 1'b0, 1'b0, 1'b1, 1'b1 };
        ahb_size        = HSIZE_32;
    end else begin
        // Decide the transfer type.
        if (tic_state == STATE_BUSY)
            ahb_trans   = TRANS_BUSY;
        else if ((tic_state == STATE_WRITE || tic_state == STATE_READ) && tic_nonseq == '1)
            ahb_trans   = TRANS_NONSEQ;
        else
            ahb_trans   = TRANS_SEQ;

        // TIC dependent signals.
        ahb_burst       = tic_burst;
        ahb_prot        = tic_prot;
        ahb_size        = tic_size;
        ahb_lock        = tic_lock;
        ahb_write       = tic_write;
        
        // Everything that isn't an IDLE is a bus request.
        ahb_busreq      = 1'b1;
    end
end

// Output assignments
assign HADDR        = tic_aphase ? tic_addr : ahb_addr_r;
assign HBURST       = ahb_burst;
assign HPROT        = ahb_prot;
assign HSIZE        = ahb_size;
assign HTRANS       = ahb_trans;
assign HWDATA       = ahb_wdata_r;
assign HWRITE       = ahb_write;
assign HBUSREQ      = ahb_busreq;
assign HLOCK        = ahb_lock;


// Input assignments.
assign ahb_rdata    = HRDATA;
assign ahb_ready    = HREADY;
assign ahb_resp     = HRESP;
assign ahb_grant    = HGRANT;

endmodule


