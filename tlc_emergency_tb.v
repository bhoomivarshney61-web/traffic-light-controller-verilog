`timescale 1ns/1ps

module tlc_emergency_tb;

    reg clk, rst_n;
    reg ns_emg, ew_emg;
    wire [2:0] ns_light, ew_light;
    wire emg_active;

    // Small timing values so the simulation log stays short and readable
    tlc_emergency #(
        .GREEN_TIME(6),
        .YELLOW_TIME(2),
        .ALLRED_TIME(1)
    ) DUT (
        .clk(clk),
        .rst_n(rst_n),
        .ns_emg(ns_emg),
        .ew_emg(ew_emg),
        .ns_light(ns_light),
        .ew_light(ew_light),
        .emg_active(emg_active)
    );

    always #5 clk = ~clk;

    function [23:0] colour_name;
        input [2:0] light;
        begin
            case (light)
                3'b100: colour_name = "RED";
                3'b010: colour_name = "YEL";
                3'b001: colour_name = "GRN";
                default: colour_name = "ERR";
            endcase
        end
    endfunction

    reg [23:0] ns_colour, ew_colour;
    always @(*) ns_colour = colour_name(ns_light);
    always @(*) ew_colour = colour_name(ew_light);

    initial begin
        $dumpfile("tlc_emergency.vcd");
        $dumpvars(0, tlc_emergency_tb);

        clk = 0; rst_n = 0; ns_emg = 0; ew_emg = 0;
        #12 rst_n = 1;

        $display("time\tNS\tEW\tEMG_ACTIVE\tevent");
        $monitor("%4t\t%s\t%s\t%b", $time, ns_colour, ew_colour, emg_active);

        #200;

        $display("\n--- Asserting ew_emg (ambulance approaching East-West) ---");
        ew_emg = 1;
        #80;
        $display("\n--- ew_emg cleared (ambulance passed) ---");
        ew_emg = 0;
        #100;

        $display("\n--- Asserting ns_emg (fire truck approaching North-South) ---");
        ns_emg = 1;
        #80;
        $display("\n--- ns_emg cleared ---");
        ns_emg = 0;
        #80;

        $display("\n--- Asserting BOTH ns_emg and ew_emg simultaneously ---");
        ns_emg = 1;
        ew_emg = 1;
        #60;
        $display("\n--- Releasing ns_emg only (ew_emg still pending) ---");
        ns_emg = 0;
        #60;
        $display("\n--- Releasing ew_emg ---");
        ew_emg = 0;
        #100;

        $display("\nSimulation finished.");
        $finish;
    end

endmodule
