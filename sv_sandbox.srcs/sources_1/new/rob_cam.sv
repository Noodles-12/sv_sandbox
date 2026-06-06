`timescale 1ns / 1ps

import config_pkg::*;

typedef struct packed { 
    logic valid;
    logic [4:0] idx;
    logic [4:0] id;
} commit_req;

typedef struct packed {
    logic valid;
    logic [4:0] idx;
    rob_entry entry;
} insert_req;

module rob_cam(
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

    rob_entry buffer [0:31];

    logic [4:0] lut [0:31];
    logic lut_valid [0:31];

    logic [4:0] head = 0, tail = 0, count = 0;

    logic full;

    assign full = (head == tail) & (count > 0);

    // Insert logics
    insert_req insert_reqs [0:1];
    logic [4:0] insert_tail;
    logic [4:0] insert_count;

    // Commit logics
    commit_req commit_reqs [0:1];
    logic [4:0] commit_head;
    logic [4:0] commit_count;

    // CDB logics
    logic [31:0] cdb_hit;
    logic [31:0] cdb_result [0:31];

    // str_rob logics
    logic [31:0] str_hit;
    logic [31:0] str_result [0:31];
    logic [11:0] str_dest [0:31];

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
            // Inserts
            for (int i = 0; i < 2; i++) begin
                if (insert_reqs[i].valid) begin
                    buffer[insert_reqs[i].idx] <= insert_reqs[i].entry;
                    lut[insert_reqs[i].entry.id] <= insert_reqs[i].idx;
                    lut_valid[insert_reqs[i].entry.id] <= 1;
                end
            end

            // Commits
            // Fix for store instructions or make memory be lut inferenced to have multiple data_mem writes
            for (int i = 0; i < 2; i++) begin
                if (commit_reqs[i].valid) begin
                    output_arr[i] <= buffer[commit_reqs[i].idx];
                    id_to_free[i] <= buffer[commit_reqs[i].idx].id;
                    lut_valid[commit_reqs[i].id] <= 0;
                    buffer[commit_reqs[i].idx] <= '0;
                end else begin
                    output_arr[i] <= '0;
                    id_to_free[i] <= '0;
                end
            end

            // CDB & str_rob updates
            for(int i = 0; i < 32; i++) begin
                if(cdb_hit[i]) begin
                    buffer[i].result <= cdb_result[i];
                    buffer[i].done <= 1;
                end

                if (str_hit[i]) begin
                    buffer[i].done <= 1;
                    buffer[i].result <= str_result[i];
                    buffer[i].mem_dest <= str_dest[i];
                end
            end

            // Update head, tail, count, amount_executed
            head <= commit_head;
            tail <= insert_tail;
            count <= count + insert_count - commit_count;
            amount_executed <= amount_executed + commit_count;
        end
    end

    // Insert block
    // Might do count another way on FF
    always_comb begin
        insert_reqs = '{default: '0};
        insert_tail = tail;
        insert_count = '0;

        // Inserting into buffer
        if(input_a.valid && !full) begin
            insert_reqs[0].valid = 1;
            insert_reqs[0].entry = input_a;
            insert_reqs[0].idx = tail;
            insert_tail = (insert_tail == 31) ? 0 : insert_tail + 1;
            insert_count = insert_count + 1;
        end

        if(input_b.valid && insert_count < 31) begin
            insert_reqs[1].valid = 1;
            insert_reqs[1].entry = input_b;
            insert_reqs[1].idx = insert_tail;
            insert_tail = (insert_tail == 31) ? 0 : insert_tail + 1;
            insert_count = insert_count + 1;
        end
    end

    // Commit block
    always_comb begin
        commit_reqs = '{default: '0};
        commit_head = head;
        commit_count = '0;

        // Iteration 0 — reads directly from registered head
        if (buffer[head].valid && buffer[head].done) begin
            commit_reqs[0].valid = 1;
            commit_reqs[0].idx = head;
            commit_reqs[0].id = buffer[head].id;
            commit_count = 1;
            commit_head = (head == 31) ? 0 : head + 1;

            // Iteration 1 — only if iter 0 committed and wasn't a store
            if (!buffer[head].is_store) begin
                if (buffer[commit_head].valid && buffer[commit_head].done) begin
                    commit_reqs[1].valid = 1;
                    commit_reqs[1].idx = commit_head;
                    commit_reqs[1].id = buffer[commit_head].id;
                    commit_count = 2;
                    commit_head = (commit_head == 31) ? 0 : commit_head + 1;
                end
            end
        end
    end

    // CDB block
    always_comb begin
        cdb_hit = '0;
        cdb_result = '{default: '0};

        for(int i = 0; i < CDB_SIZE; i++) begin
            if (!cdb_arr[i].valid) continue;
            if (!lut_valid[cdb_arr[i].id]) continue;

            cdb_hit[lut[cdb_arr[i].id]] = 1;
            cdb_result[lut[cdb_arr[i].id]] = cdb_arr[i].result;
        end
    end

    // str_rob block
    always_comb begin
        str_hit = '0;
        str_result = '{default: '0};
        str_dest = '{default: '0};

        for (int i = 0; i < 2; i++) begin
            if (!str_rob[i].valid) continue;
            if (!lut_valid[str_rob[i].id]) continue;

            str_hit[lut[str_rob[i].id]] = 1;
            str_result[lut[str_rob[i].id]] = str_rob[i].mem_dest;
            str_dest[lut[str_rob[i].id]] = str_rob[i].mem_dest;
        end
    end
endmodule

