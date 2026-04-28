-------------------------------------------------
--! @file debounce.vhd
--! @brief Single-button synchronizer, debouncer, and press-pulse generator.
--! @description
--! Filters a mechanical push-button input before it is used by the control
--! FSM. The raw input is first synchronized to clk, then sampled at a slower
--! rate and passed through a short shift-register filter. The module outputs
--! both the debounced button level and a one-clock pulse on each new press.
--!
--! Main behavior:
--! - btn_in is the raw, potentially bouncing button input.
--! - btn_state is the stable debounced level.
--! - btn_press is high for one clock cycle on a rising button press.
--! - G_SAMPLE_MAX sets the sampling interval through the clk_en component.
--!
--! Relevant notes:
--! - G_SAMPLE_MAX = 200_000 is about 2 ms at 100 MHz.
--! - A small G_SAMPLE_MAX, for example 2, is useful in simulation.
--! - C_SHIFT_LEN = 4 requires four consistent sampled values before change.
--!
--! @copyright Kapana, Glaser 2026
-------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity debounce is
    generic (
        G_SAMPLE_MAX : positive := 200_000
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        btn_in    : in  std_logic;  -- bouncy raw input
        btn_state : out std_logic;  -- debounced level
        btn_press : out std_logic   -- one-clock pulse on press
    );
end entity debounce;

architecture Behavioral of debounce is

    constant C_SHIFT_LEN : positive := 4;

    signal ce_sample : std_logic;
    signal sync0     : std_logic;
    signal sync1     : std_logic;
    signal shift_reg : std_logic_vector(C_SHIFT_LEN-1 downto 0);
    signal debounced : std_logic;
    signal delayed   : std_logic;

begin

    ----------------------------------------------------------------
    -- Sampling clock enable (inline, no separate component)
    ----------------------------------------------------------------
    u_sample_ce : entity work.clk_en
        generic map ( G_MAX => G_SAMPLE_MAX )
        port map (
            clk => clk,
            rst => rst,
            ce  => ce_sample
        );

    ----------------------------------------------------------------
    -- Synchronizer + debounce
    ----------------------------------------------------------------
    p_debounce : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                sync0     <= '0';
                sync1     <= '0';
                shift_reg <= (others => '0');
                debounced <= '0';
                delayed   <= '0';
            else
                -- input synchronizer
                sync1 <= sync0;
                sync0 <= btn_in;

                -- sample shift register
                if ce_sample = '1' then
                    shift_reg <= shift_reg(C_SHIFT_LEN-2 downto 0) & sync1;

                    if shift_reg = (shift_reg'range => '1') then
                        debounced <= '1';
                    elsif shift_reg = (shift_reg'range => '0') then
                        debounced <= '0';
                    end if;
                end if;

                -- one-cycle delayed copy for edge detection
                delayed <= debounced;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------
    -- Outputs
    ----------------------------------------------------------------
    btn_state <= debounced;
    btn_press <= debounced and not delayed;

end architecture Behavioral;
