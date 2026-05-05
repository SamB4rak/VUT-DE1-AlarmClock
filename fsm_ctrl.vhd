-------------------------------------------------
--! @brief Alarm clock main FSM controller
--! @version 1.0
--! @copyright (c) 2026 Jarda, MIT license
--!
--! Manages four states:
--!   RUN        : time counts, alarm compared, display normal
--!   SET_TIME   : SW(0)=1, edit time digits with U/D/L/R/C buttons
--!   SET_ALARM  : entered by btnc from RUN, edit alarm digits
--!   ALARM_RING : reached when match=1 and alarm_armed=1
--!
--! Inputs (button pulses, single-clock):
--!   btn_press(4) = btnc
--!   btn_press(3) = btnr
--!   btn_press(2) = btnl
--!   btn_press(1) = btnd
--!   btn_press(0) = btnu
--!
--! Outputs:
--!   time_inc/dec, alarm_inc/dec     -- pulses to BCD counters
--!   time_run                        -- '1' in RUN state -> auto count
--!   digit_sel(1:0)                  -- which digit is being edited
--!   state_out(1:0)                  -- current state (for display_mux)
--!   alarm_ringing                   -- '1' in ALARM_RING state
--!   alarm_armed                     -- '1' if alarm is set and active
-------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fsm_ctrl is
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;

        -- Inputs
        btn_press    : in  std_logic_vector(4 downto 0);
        sw_mode      : in  std_logic;   -- SW(0): '1' enters SET_TIME
        match        : in  std_logic;   -- from comparator

        -- Outputs to time_counter
        time_inc     : out std_logic;
        time_dec     : out std_logic;
        time_run     : out std_logic;

        -- Outputs to alarm_reg
        alarm_inc    : out std_logic;
        alarm_dec    : out std_logic;

        -- Outputs to display_mux
        digit_sel    : out std_logic_vector(1 downto 0);
        state_out    : out std_logic_vector(1 downto 0);

        -- Alarm flags
        alarm_ringing : out std_logic;
        alarm_armed   : out std_logic
    );
end entity fsm_ctrl;

architecture Behavioral of fsm_ctrl is

    -- State encoding (must match display_mux)
    constant ST_RUN  : std_logic_vector(1 downto 0) := "00";
    constant ST_SETT : std_logic_vector(1 downto 0) := "01";
    constant ST_SETA : std_logic_vector(1 downto 0) := "10";
    constant ST_RING : std_logic_vector(1 downto 0) := "11";

    signal state    : std_logic_vector(1 downto 0);
    signal next_st  : std_logic_vector(1 downto 0);

    signal dsel     : unsigned(1 downto 0);
    signal armed    : std_logic;

    -- Convenient button aliases
    alias btnu_p : std_logic is btn_press(0);
    alias btnd_p : std_logic is btn_press(1);
    alias btnl_p : std_logic is btn_press(2);
    alias btnr_p : std_logic is btn_press(3);
    alias btnc_p : std_logic is btn_press(4);

begin

    ----------------------------------------------------------------
    -- State register + alarm_armed register + digit_sel register
    ----------------------------------------------------------------
    p_state : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= ST_RUN;
                dsel  <= (others => '0');
                armed <= '0';
            else
                ----------------------------------------------------
                -- State transitions
                ----------------------------------------------------
                case state is

                    when ST_RUN =>
                        if sw_mode = '1' then
                            state <= ST_SETT;
                            dsel  <= (others => '0');
                        elsif btnc_p = '1' then
                            state <= ST_SETA;
                            dsel  <= (others => '0');
                        elsif match = '1' and armed = '1' then
                            state <= ST_RING;
                        end if;

                    when ST_SETT =>
                        if sw_mode = '0' then
                            state <= ST_RUN;
                        else
                            -- digit navigation
                            if btnl_p = '1' then
                                if dsel = 0 then
                                    dsel <= to_unsigned(3, 2);
                                else
                                    dsel <= dsel - 1;
                                end if;
                            elsif btnr_p = '1' then
                                if dsel = 3 then
                                    dsel <= (others => '0');
                                else
                                    dsel <= dsel + 1;
                                end if;
                            end if;
                        end if;

                    when ST_SETA =>
                        if btnc_p = '1' then
                            state <= ST_RUN;
                            armed <= '1';      -- arm the alarm on confirm
                        else
                            if btnl_p = '1' then
                                if dsel = 0 then
                                    dsel <= to_unsigned(3, 2);
                                else
                                    dsel <= dsel - 1;
                                end if;
                            elsif btnr_p = '1' then
                                if dsel = 3 then
                                    dsel <= (others => '0');
                                else
                                    dsel <= dsel + 1;
                                end if;
                            end if;
                        end if;

                    when ST_RING =>
                        if btnc_p = '1' then
                            state <= ST_RUN;
                            armed <= '0';      -- disarm on dismiss
                        end if;

                    when others =>
                        state <= ST_RUN;
                end case;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------
    -- Output combinational logic
    ----------------------------------------------------------------
    p_out : process(state, btnu_p, btnd_p)
    begin
        -- defaults
        time_inc  <= '0';
        time_dec  <= '0';
        time_run  <= '0';
        alarm_inc <= '0';
        alarm_dec <= '0';

        case state is
            when ST_RUN =>
                time_run <= '1';

            when ST_SETT =>
                if btnu_p = '1' then time_inc <= '1'; end if;
                if btnd_p = '1' then time_dec <= '1'; end if;

            when ST_SETA =>
                time_run <= '1';
                if btnu_p = '1' then alarm_inc <= '1'; end if;
                if btnd_p = '1' then alarm_dec <= '1'; end if;

            when ST_RING =>
                time_run <= '1';   -- keep time running while ringing

            when others => null;
        end case;
    end process;

    ----------------------------------------------------------------
    -- Direct outputs
    ----------------------------------------------------------------
    state_out     <= state;
    digit_sel     <= std_logic_vector(dsel);
    alarm_armed   <= armed;
    alarm_ringing <= '1' when state = ST_RING else '0';

end architecture Behavioral;
