library ieee;
  use ieee.std_logic_1164.all;

library tinyuart;
  use tinyuart.tinyuart.all;

entity tb_tx is
end entity;

architecture test of tb_tx is

  constant CLK_PERIOD : time := 100 ns;
  signal clk : std_logic := '0';

  constant BAUDRATE_PERIOD : time := 8.68055 us; -- 115200
  constant CYCLES_PER_BAUD : positive := BAUDRATE_PERIOD / CLK_PERIOD;

  signal t : transmitter_t := init(CYCLES_PER_BAUD);

  signal ibyte : std_logic_vector(7 downto 0) := b"01011001";
  signal ibyte_valid : std_logic := '0';

  signal rx : std_logic_vector(7 downto 0);

begin

  clk <= not clk after CLK_PERIOD / 2;


  DUT : process (clk) is
  begin
    if rising_edge(clk) then
      t <= clock(t, ibyte, ibyte_valid);
    end if;
  end process;


  Main : process is
  begin
    wait for CLK_PERIOD;

    for i in 0 to 5 loop
      wait for CLK_PERIOD;
      assert t.tx = '1'
        report "tx must be '1' in idle state, current value " & t.tx'image
        severity failure;
    end loop;

    ibyte_valid <= '1';
    wait until rising_edge(clk) and ibyte_valid = '1' and t.ibyte_ready = '1';
    ibyte_valid <= '0';
    wait for 2 * CLK_PERIOD;

    -- Start bit
    assert t.tx = '0'
      report "invalid start bit value, got " & t.tx'image & ", want '0'"
      severity failure;
    wait for BAUDRATE_PERIOD;

    -- Byte
    for i in 0 to 7 loop
      report "sampling bit " & i'image & ": " & t.tx'image;
      rx(i) <= t.tx;
      wait for BAUDRATE_PERIOD;
    end loop;
    wait for 0 ns;
    assert rx = ibyte
      report "invalid rx byte, got " & rx'image & ", want " & ibyte'image
      severity failure;

    -- Start bit
    assert t.tx = '1'
      report "invalid stop bit value, got " & t.tx'image & ", want '1'"
      severity failure;

    wait for 2 * BAUDRATE_PERIOD;

    std.env.finish;
  end process;

end architecture;
