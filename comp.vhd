-------------------------------------------------
--! @brief Equality comparator for time vs alarm
--! @version 1.0
--! @copyright (c)
--!
--! Purely combinational. Outputs match='1' when the
--! current time equals the alarm time.
-------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity comp is
    port (
        time_in  : in  std_logic_vector(15 downto 0);
        alarm_in : in  std_logic_vector(15 downto 0);
        match    : out std_logic
    );
end entity comp;

architecture Behavioral of comp is
begin
    match <= '1' when (time_in = alarm_in) else '0';
end architecture Behavioral;
