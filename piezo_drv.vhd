-------------------------------------------------
--! @brief Piezo buzzer melody driver - Beethoven's 5th
--! @version 3.2
--! @copyright (c) 2026 Jarda, MIT license
--!
--! Plays the iconic opening motif of Beethoven's
--! 5th Symphony ("da-da-da-DUM  da-da-da-DUM")
--! on the piezo while ringing='1'.
--!
--! When ringing='0' the output is held at '0'
--! and the internal sequencer is reset.
--
-- Original notation (transposed up one octave for
-- louder output - piezo elements have their resonant
-- peak in the kHz range, so higher pitch = louder):
--   First motif : G5-G5-G5-Eb5   (eighth-eighth-eighth-half/fermata)
--   Second motif: F5-F5-F5-D5    (eighth-eighth-eighth-half/fermata)
--
-- v3.1: staccato gaps between repeated notes.
-- v3.2: whole melody transposed +1 octave for louder
--       playback on the Nexys A7-50T piezo.
--
-- Notes:
-- - Designed for 100 MHz clk (Nexys A7-50T).
-- - Frequencies are approximate (rounded to integer
--   half-period counts), perfectly fine for a piezo.
-- - For simulation use a small G_SIM_DIV (>=1) to
--   speed up the whole sequencer without rewriting
--   the table.  G_SIM_DIV=1 -> real-time behaviour.
-------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity piezo_drv is
    generic (
        --! Kept for backward-compatibility with the top-level.
        --! No longer used internally (melody has its own table),
        --! but left here so the existing port/generic map still
        --! compiles unchanged.
        G_HALF_PERIOD : positive := 50_000;

        --! Simulation speed-up divisor for note durations.
        --! 1 = real timing, larger values shorten notes.
        G_SIM_DIV     : positive := 1
    );
    port (
        clk     : in  std_logic;
        rst     : in  std_logic;
        ringing : in  std_logic;
        piezo   : out std_logic
    );
end entity piezo_drv;

architecture Behavioral of piezo_drv is

    --------------------------------------------------------------
    -- Tone half-period constants for 100 MHz clock
    --   half_period = 100_000_000 / (2 * f_tone)
    --
    --   G5  ~ 784.00 Hz  ->   63_776
    --   Eb5 ~ 622.25 Hz  ->   80_354
    --   F5  ~ 698.46 Hz  ->   71_586
    --   D5  ~ 587.33 Hz  ->   85_131
    --------------------------------------------------------------
    constant C_HP_G5   : integer := 63_776;
    constant C_HP_EB5  : integer := 80_354;
    constant C_HP_F5   : integer := 71_586;
    constant C_HP_D5   : integer := 85_131;
    constant C_HP_REST : integer := 0;       -- 0 means silence

    --------------------------------------------------------------
    -- Note duration in 100 MHz clock cycles
    -- 100_000_000 cycles = 1 s
    --
    -- Tempo ~ allegro con brio (Beethoven's marking):
    --   short note  (eighth, audible part)  ~110 ms
    --   micro rest  (staccato gap)          ~ 30 ms
    --   long  note  (half/fermata)          ~700 ms
    --   medium rest (between two motifs)    ~250 ms
    --   long rest   (before melody loop)    ~600 ms
    --
    -- Together short + micro rest ~140 ms = original "da" length.
    --------------------------------------------------------------
    constant C_DUR_SHORT       : integer := 11_000_000;
    constant C_DUR_MICRO_REST  : integer :=  3_000_000;
    constant C_DUR_LONG        : integer := 70_000_000;
    constant C_DUR_MID_REST    : integer := 25_000_000;
    constant C_DUR_LONG_REST   : integer := 60_000_000;

    --------------------------------------------------------------
    -- Melody table:  (half_period, duration_in_clk_cycles)
    --------------------------------------------------------------
    type t_note is record
        hp  : integer;   -- half-period count, 0 = silence
        dur : integer;   -- duration in clk cycles
    end record;

    type t_melody is array (natural range <>) of t_note;

    constant C_MELODY : t_melody := (
         0 => (C_HP_G5,   C_DUR_SHORT),       -- G  "da"
         1 => (C_HP_REST, C_DUR_MICRO_REST),  -- gap
         2 => (C_HP_G5,   C_DUR_SHORT),       -- G  "da"
         3 => (C_HP_REST, C_DUR_MICRO_REST),  -- gap
         4 => (C_HP_G5,   C_DUR_SHORT),       -- G  "da"
         5 => (C_HP_REST, C_DUR_MICRO_REST),  -- gap
         6 => (C_HP_EB5,  C_DUR_LONG),        -- Eb "DUM" (fermata)
         7 => (C_HP_REST, C_DUR_MID_REST),    -- breath
         8 => (C_HP_F5,   C_DUR_SHORT),       -- F  "da"
         9 => (C_HP_REST, C_DUR_MICRO_REST),  -- gap
        10 => (C_HP_F5,   C_DUR_SHORT),       -- F  "da"
        11 => (C_HP_REST, C_DUR_MICRO_REST),  -- gap
        12 => (C_HP_F5,   C_DUR_SHORT),       -- F  "da"
        13 => (C_HP_REST, C_DUR_MICRO_REST),  -- gap
        14 => (C_HP_D5,   C_DUR_LONG),        -- D  "DUM" (fermata)
        15 => (C_HP_REST, C_DUR_LONG_REST)    -- long rest, then loop
    );

    constant C_LAST : integer := C_MELODY'high;

    --------------------------------------------------------------
    -- Sequencer signals
    --------------------------------------------------------------
    signal note_idx : integer range 0 to C_LAST := 0;
    signal dur_cnt  : unsigned(31 downto 0)     := (others => '0');
    signal tone_cnt : unsigned(31 downto 0)     := (others => '0');
    signal toggle   : std_logic                 := '0';

begin

    --------------------------------------------------------------
    -- Main process: walks through the melody table, generates
    -- the square wave for the current note's frequency, and
    -- advances to the next note when its duration expires.
    --------------------------------------------------------------
    p_melody : process(clk)
        variable v_dur_target : unsigned(31 downto 0);
        variable v_hp_target  : unsigned(31 downto 0);
    begin
        if rising_edge(clk) then

            -- Target values for the *current* note, scaled for sim
            v_dur_target :=
                to_unsigned(C_MELODY(note_idx).dur / G_SIM_DIV, 32);
            v_hp_target  :=
                to_unsigned(C_MELODY(note_idx).hp,  32);

            if rst = '1' then
                note_idx <= 0;
                dur_cnt  <= (others => '0');
                tone_cnt <= (others => '0');
                toggle   <= '0';

            elsif ringing = '1' then

                ----------------------------------------------------
                -- Tone (square wave) generation
                ----------------------------------------------------
                if C_MELODY(note_idx).hp = 0 then
                    -- Rest: hold output low
                    tone_cnt <= (others => '0');
                    toggle   <= '0';
                else
                    if tone_cnt >= v_hp_target - 1 then
                        tone_cnt <= (others => '0');
                        toggle   <= not toggle;
                    else
                        tone_cnt <= tone_cnt + 1;
                    end if;
                end if;

                ----------------------------------------------------
                -- Note duration / sequencer
                ----------------------------------------------------
                if dur_cnt >= v_dur_target - 1 then
                    dur_cnt  <= (others => '0');
                    tone_cnt <= (others => '0');
                    toggle   <= '0';
                    if note_idx = C_LAST then
                        note_idx <= 0;          -- loop the melody
                    else
                        note_idx <= note_idx + 1;
                    end if;
                else
                    dur_cnt <= dur_cnt + 1;
                end if;

            else
                -- ringing = '0': silence and reset sequencer
                note_idx <= 0;
                dur_cnt  <= (others => '0');
                tone_cnt <= (others => '0');
                toggle   <= '0';
            end if;
        end if;
    end process;

    piezo <= toggle;

end architecture Behavioral;