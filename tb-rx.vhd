library ieee;
  use ieee.std_logic_1164.all;

library tinyuart;
  use tinyuart.tinyuart.all;

entity tb_rx is
end entity;

architecture test of tb_rx is

  constant CLK_PERIOD : time := 100 ns;
  signal clk : std_logic := '0';

  constant BAUDRATE_PERIOD : time := 8.68055 us; -- 115200
  constant CYCLES_PER_BAUD : positive := BAUDRATE_PERIOD / CLK_PERIOD;

  signal r : receiver_t := init(CYCLES_PER_BAUD);

  signal ibyte : std_logic_vector(7 downto 0) := b"01100101";
  signal obyte : std_logic_vector(7 downto 0);
  signal obyte_ready : std_logic := '0';

  signal rx : std_logic := '1';

begin

  clk <= not clk after CLK_PERIOD / 2;


  DUT : process (clk) is
  begin
    if rising_edge(clk) then
      r <= clock(r, rx, obyte_ready);
    end if;
  end process;


  Stop_Bit_Checker : process (clk) is
  begin
    if rising_edge(clk) then
      assert r.stop_bit_err = '0'
        report "invalid stop bit err value, got " & r.stop_bit_err'image & "want '1'"
        severity failure;
    end if;
  end process;


  Main : process is
  begin
    wait for BAUDRATE_PERIOD;

    -- Start bit
    rx <= '0';
    wait for BAUDRATE_PERIOD;

    for i in 0 to 7 loop
      rx <= ibyte(i);
      wait for BAUDRATE_PERIOD;
    end loop;

    -- Stop bit
    rx <= '1';
    wait for BAUDRATE_PERIOD;

    obyte_ready <= '1';
    wait until rising_edge(clk) and obyte_ready = '1' and r.obyte_valid = '1';
    obyte <= r.obyte;
    wait for CLK_PERIOD;
    assert obyte = ibyte
      report "invalid output byte, got " & obyte'image & ", want " & ibyte'image
      severity failure;

    wait for 2 * BAUDRATE_PERIOD;

    std.env.finish;
  end process;

end architecture;