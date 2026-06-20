module tlc_emergency #(
    parameter GREEN_TIME   = 8,   // clock cycles light stays green (normal cycle)
    parameter YELLOW_TIME  = 3,   // clock cycles light stays yellow
    parameter ALLRED_TIME  = 2    // clock cycles all-red clearance interval
)(
    input  wire clk,
    input  wire rst_n,      // active-low async reset
    input  wire ns_emg,     // emergency sensor, North-South road
    input  wire ew_emg,     // emergency sensor, East-West road

    output reg [2:0] ns_light,   // {Red, Yellow, Green} one-hot
    output reg [2:0] ew_light,   // {Red, Yellow, Green} one-hot
    output reg        emg_active // HIGH whenever controller is in an
                                  // emergency-preemption phase (for ERP/log)
);

    localparam RED    = 3'b100;
    localparam YELLOW  = 3'b010;
    localparam GREEN   = 3'b001;

    localparam S_NS_GREEN   = 4'd0;
    localparam S_NS_YELLOW  = 4'd1;
    localparam S_ALLRED_A   = 4'd2;  // clearance: NS->EW
    localparam S_EW_GREEN   = 4'd3;
    localparam S_EW_YELLOW  = 4'd4;
    localparam S_ALLRED_B   = 4'd5;  // clearance: EW->NS
    localparam S_EMG_NS     = 4'd6;  // emergency green held for NS
    localparam S_EMG_EW     = 4'd7;  // emergency green held for EW

    reg [3:0] state, next_state;
    reg [$clog2(GREEN_TIME+1)-1:0] timer;
    wire timer_done;

    reg [$clog2(GREEN_TIME+1)-1:0] load_value;

    always @(*) begin
        case (next_state)
            S_NS_GREEN, S_EW_GREEN                : load_value = GREEN_TIME[$clog2(GREEN_TIME+1)-1:0]  - 1;
            S_NS_YELLOW, S_EW_YELLOW               : load_value = YELLOW_TIME[$clog2(GREEN_TIME+1)-1:0] - 1;
            S_ALLRED_A, S_ALLRED_B                 : load_value = ALLRED_TIME[$clog2(GREEN_TIME+1)-1:0] - 1;
            default                                : load_value = 0; // EMG states: no fixed timer, sensor controlled
        endcase
    end

    assign timer_done = (timer == 0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            timer <= GREEN_TIME - 1;
        else if (state != next_state)
            timer <= load_value;        // reload on every state change
        else if (!timer_done)
            timer <= timer - 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= S_NS_GREEN;
        else
            state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)

            S_NS_GREEN: begin
                if (ew_emg)                 next_state = S_NS_YELLOW;   // start clearance for EW emergency
                else if (ns_emg)             next_state = S_EMG_NS;      // already correct colour, latch emg mode
                else if (timer_done)         next_state = S_NS_YELLOW;
            end

            S_NS_YELLOW: begin
                if (timer_done)              next_state = S_ALLRED_A;
            end

            S_ALLRED_A: begin
                if (timer_done) begin
                    if (ns_emg)               next_state = S_EMG_NS;     // NS priority
                    else if (ew_emg)          next_state = S_EMG_EW;
                    else                      next_state = S_EW_GREEN;
                end
            end

            S_EW_GREEN: begin
                if (ns_emg)                  next_state = S_EW_YELLOW;   // start clearance for NS emergency
                else if (ew_emg)              next_state = S_EMG_EW;
                else if (timer_done)          next_state = S_EW_YELLOW;
            end

            S_EW_YELLOW: begin
                if (timer_done)               next_state = S_ALLRED_B;
            end

            S_ALLRED_B: begin
                if (timer_done) begin
                    if (ns_emg)               next_state = S_EMG_NS;
                    else if (ew_emg)          next_state = S_EMG_EW;
                    else                      next_state = S_NS_GREEN;
                end
            end

            S_EMG_NS: begin
                if (!ns_emg)                  next_state = S_NS_YELLOW;  // vehicle cleared, resume cycle safely
            end

            S_EMG_EW: begin
                if (!ew_emg)                  next_state = S_EW_YELLOW;
            end

            default: next_state = S_NS_GREEN;
        endcase
    end

    always @(*) begin
        ns_light  = RED;
        ew_light  = RED;
        emg_active = 1'b0;

        case (state)
            S_NS_GREEN:  begin ns_light = GREEN;  ew_light = RED;    end
            S_NS_YELLOW: begin ns_light = YELLOW; ew_light = RED;    end
            S_ALLRED_A:  begin ns_light = RED;    ew_light = RED;    end
            S_EW_GREEN:  begin ns_light = RED;    ew_light = GREEN;  end
            S_EW_YELLOW: begin ns_light = RED;    ew_light = YELLOW; end
            S_ALLRED_B:  begin ns_light = RED;    ew_light = RED;    end
            S_EMG_NS:    begin ns_light = GREEN;  ew_light = RED;    emg_active = 1'b1; end
            S_EMG_EW:    begin ns_light = RED;    ew_light = GREEN;  emg_active = 1'b1; end
            default:     begin ns_light = RED;    ew_light = RED;    end
        endcase
    end

endmodule
