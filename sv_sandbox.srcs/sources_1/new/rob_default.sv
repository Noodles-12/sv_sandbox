`timescale 1ns / 1ps

import config_pkg::*;

module rob_default(
    input logic clk,
    input logic rst,
    input rob_entry input_a,
    input rob_entry input_b,
    input cdb_entry cdb_arr [0:CDB_SIZE - 1],
    input str_disp_entry str_rob [0:1],
    
    output logic [3:0] amount_executed,
    output rob_entry output_arr [0:1],
    output logic [4:0] id_to_free [0:1]
);

    rob_entry buffer [0:31], next_buffer [0:31];

    logic [4:0] lut [0:31], next_lut [0:31];
    logic lut_valid [0:31], next_lut_valid[0:31];

    rob_entry comb_output_arr [0:1];
    logic [4:0] comb_id_to_free [0:1];
    logic [3:0] next_amount_executed;

    logic [4:0] head = 0, tail = 0, count = 0;
    logic [4:0] next_head, next_tail, next_count;

    logic empty, full, done;

    assign empty = (head == tail) & (count == 0);
    assign full = (head == tail) & (count > 0);

    always_ff @ (posedge clk) begin
        if (rst) begin
            buffer <= '{default: '0};
            head <= '0;
            tail <= '0;
            count <= '0;

            output_arr <= '{default: '0};
            id_to_free <= '{default: '0};

            lut <= '{default: '0};
            lut_valid <= '{default: '0};

            amount_executed <= '0;
        end else begin
            buffer <= next_buffer;
            head <= next_head;
            tail <= next_tail;
            count <= next_count;


            output_arr <= comb_output_arr;
            id_to_free <= comb_id_to_free;

            lut <= next_lut;
            lut_valid <= next_lut_valid;

            amount_executed <= next_amount_executed;
        end
    end

    always_comb begin
        next_buffer = buffer;
        next_head = head;
        next_tail = tail;
        next_count = count;

        done = 0;
        comb_output_arr = '{default: '0};
        comb_id_to_free = '{default: '0};
        next_amount_executed = amount_executed;

        next_lut = lut;
        next_lut_valid = lut_valid;

        // Inserting into buffer
        if(input_a.valid && !full) begin
            next_buffer[next_tail] = input_a;
            next_lut[input_a.id] = next_tail;
            next_lut_valid[input_a.id] = 1;
            next_tail = (next_tail == 31) ? 0 : next_tail + 1;
            next_count++;
        end

        if(input_b.valid && !full) begin
            next_buffer[next_tail] = input_b;
            next_lut[input_b.id] = next_tail;
            next_lut_valid[input_b.id] = 1;
            next_tail = (next_tail == 31) ? 0 : next_tail + 1;
            next_count++;
        end

        // Pushing into commit (removing)
        for(int i = 0; i < 2; i++) begin
            if(!done && next_buffer[next_head].done == 1) begin             
                comb_output_arr[i] = next_buffer[next_head];
                comb_id_to_free[i] = next_buffer[next_head].id;
                next_buffer[next_head] = '0;
                next_head = (next_head == 31) ? 0 : next_head + 1;
                next_amount_executed = next_amount_executed + 1;
                next_count--;

                // Stop committing if we just committed a store
                if(comb_output_arr[i].is_store)
                    done = 1;
            end else begin
                comb_output_arr[i] = '0;
                comb_id_to_free[i] = '0;
                done = 1;
            end
        end

        // Changing with CDB info
        for(int i = 0; i < CDB_SIZE; i++) begin
            if(cdb_arr[i].valid == 0) continue;

            next_buffer[next_lut[cdb_arr[i].id]].result = cdb_arr[i].result;
            next_buffer[next_lut[cdb_arr[i].id]].done = 1;
        end

        // Changing with str_rob info
        for(int i = 0; i < 2; i++) begin
            if(str_rob[i].valid == 0) continue;

            next_buffer[next_lut[str_rob[i].id]].mem_dest = str_rob[i].mem_dest;
            next_buffer[next_lut[str_rob[i].id]].result = str_rob[i].mem_dest;
            next_buffer[next_lut[str_rob[i].id]].done = 1;
        end
    end
endmodule