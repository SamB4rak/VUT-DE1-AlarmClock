-------------------------------------------------
--! @brief Alarm clock top-level
--! @version 1.0
--! @copyright (c) 2026 Jarda, MIT license
--!
--! Connects all subcomponents:
--!   - 5x debounce (one per push button)
--!   - 2x clk_en (1 Hz, 2 Hz)
--!   - fsm_ctrl
--!   - time_counter
--!   - alarm_reg
--!   - comp
--!   - display_mux
--!   - piezo_drv
--!
--! Targets Nexys A7-50T (100 MHz clk).
--! Pin assignment is in alarm_clock_top.xdc.
-------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity alarm_clock_top is
    port (
        clk   : in  std_logic;
        rst   : in  std_logic;

        -- 5-way push button pad
        btnu  : in  std_logic;
        btnd  : in  std_logic;
        btnl  : in  std_logic;
        btnr  : in  std_logic;
        btnc  : in  std_logic;

        -- Mode switch
        sw    : in  std_logic_vector(0 downto 0);

        -- 7-segment display
        seg   : out std_logic_vector(6 downto 0);
        an    : out std_logic_vector(7 downto 0);
        dp    : out std_logic;

        -- Piezo buzzer
        piezo : out std_logic
    );
end entity alarm_clock_top;

architecture Behavioral of alarm_clock_top is

    --------------------------------------------------------------
    -- Internal signals
    --------------------------------------------------------------
    -- Buttons combined into a single bus for easy generate-loop
    signal btn_raw   : std_logic_vector(4 downto 0);
    signal btn_press : std_logic_vector(4 downto 0);
    signal btn_state : std_logic_vector(4 downto 0);

    -- Clock enables
    signal ce_1hz   : std_logic;
    signal ce_blink : std_logic;

    -- FSM <-> counters
    signal time_inc  : std_logic;
    signal time_dec  : std_logic;
    signal time_run  : std_logic;
    signal alarm_inc : std_logic;
    signal alarm_dec : std_logic;

    -- FSM <-> display
    signal digit_sel : std_logic_vector(1 downto 0);
    signal state_w   : std_logic_vector(1 downto 0);
    signal armed_w   : std_logic;
    signal ringing_w : std_logic;

    -- Time/alarm data
    signal time_w  : std_logic_vector(15 downto 0);
    signal alarm_w : std_logic_vector(15 downto 0);

    -- Match signal
    signal match_w : std_logic;

begin

    --------------------------------------------------------------
    -- Combine raw buttons into one vector
    -- Order MUST match fsm_ctrl alias declarations:
    --   btn_press(0) = btnu
    --   btn_press(1) = btnd
    --   btn_press(2) = btnl
    --   btn_press(3) = btnr
    --   btn_press(4) = btnc
    --------------------------------------------------------------
    btn_raw(0) <= btnu;
    btn_raw(1) <= btnd;
    btn_raw(2) <= btnl;
    btn_raw(3) <= btnr;
    btn_raw(4) <= btnc;

    --------------------------------------------------------------
    -- 5x debounce instances via for-generate
    --------------------------------------------------------------
    gen_debounce : for i in 0 to 4 generate
        u_deb : entity work.debounce
            generic map (
                G_SAMPLE_MAX => 200_000   -- ~2 ms at 100 MHz
            )
            port map (
                clk       => clk,
                rst       => rst,
                btn_in    => btn_raw(i),
                btn_state => btn_state(i),
                btn_press => btn_press(i)
            );
    end generate;

    --------------------------------------------------------------
    -- Clock enable for 1 Hz time counting + colon blink
    --------------------------------------------------------------
    u_ce_1hz : entity work.clk_en
        generic map (
            G_MAX => 50_000_000    -- 1 Hz from 100 MHz
        )
        port map (
            clk => clk,
            rst => rst,
            ce  => ce_1hz
        );

    --------------------------------------------------------------
    -- Clock enable for 2 Hz blink
    --------------------------------------------------------------
    u_ce_blink : entity work.clk_en
        generic map (
            G_MAX => 25_000_000    -- 2 Hz from 100 MHz
        )
        port map (
            clk => clk,
            rst => rst,
            ce  => ce_blink
        );

    --------------------------------------------------------------
    -- FSM controller
    --------------------------------------------------------------
    u_fsm : entity work.fsm_ctrl
        port map (
            clk           => clk,
            rst           => rst,
            btn_press     => btn_press,
            sw_mode       => sw(0),
            match         => match_w,
            time_inc      => time_inc,
            time_dec      => time_dec,
            time_run      => time_run,
            alarm_inc     => alarm_inc,
            alarm_dec     => alarm_dec,
            digit_sel     => digit_sel,
            state_out     => state_w,
            alarm_ringing => ringing_w,
            alarm_armed   => armed_w
        );

    --------------------------------------------------------------
    -- Time counter
    --------------------------------------------------------------
    u_time : entity work.time_counter
        port map (
            clk       => clk,
            rst       => rst,
            ce_run    => ce_1hz,
            run_en    => time_run,
            inc_en    => time_inc,
            dec_en    => time_dec,
            digit_sel => digit_sel,
            time_out  => time_w
        );

    --------------------------------------------------------------
    -- Alarm register
    --------------------------------------------------------------
    u_alarm : entity work.alarm_reg
        port map (
            clk       => clk,
            rst       => rst,
            inc_en    => alarm_inc,
            dec_en    => alarm_dec,
            digit_sel => digit_sel,
            alarm_out => alarm_w
        );

    --------------------------------------------------------------
    -- Comparator
    --------------------------------------------------------------
    u_comp : entity work.comp
        port map (
            time_in  => time_w,
            alarm_in => alarm_w,
            match    => match_w
        );

    --------------------------------------------------------------
    -- Display multiplexer
    --------------------------------------------------------------
    u_disp : entity work.display_mux
        generic map (
            G_MUX_MAX => 100_000      -- ~1 kHz refresh
        )
        port map (
            clk         => clk,
            rst         => rst,
            time_in     => time_w,
            alarm_in    => alarm_w,
            state       => state_w,
            digit_sel   => digit_sel,
            ce_1hz      => ce_1hz,
            ce_blink    => ce_blink,
            alarm_armed => armed_w,
            seg         => seg,
            an          => an,
            dp          => dp
        );

    --------------------------------------------------------------
    -- Piezo driver
    --------------------------------------------------------------
    u_piezo : entity work.piezo_drv
        generic map (
            G_HALF_PERIOD => 50_000   -- ~1 kHz tone
        )
        port map (
            clk     => clk,
            rst     => rst,
            ringing => ringing_w,
            piezo   => piezo
        );

end architecture Behavioral;
