library ieee;
  use ieee.std_logic_1164.all;

library tinyuart;
  use tinyuart.tinyuart.all;

entity tb_loopback is
end entity;

architecture test of tb_loopback is

  constant CLK_PERIOD : time := 100 ns;
  signal clk : std_logic := '0';

  constant BAUDRATE_PERIOD : time := 8.68055 us; -- 115200
  constant CYCLES_PER_BAUD : positive := BAUDRATE_PERIOD / CLK_PERIOD;

  signal t : transmitter_t := init(CYCLES_PER_BAUD);
  signal r : receiver_t := init(CYCLES_PER_BAUD);

  type data_array_t is array (natural range <>) of std_logic_vector(7 downto 0);

  constant idata : data_array_t(0 to 3) := (b"00001111", b"10101010", b"00110011", b"11001100");
  signal   odata : data_array_t(0 to 3);

  signal ibyte : std_logic_vector(7 downto 0);
  signal ibyte_valid : std_logic := '0';

  signal obyte_ready : std_logic;

begin

  clk <= not clk after CLK_PERIOD / 2;


  Transmitter : process (clk) is
  begin
    if rising_edge(clk) then
      t <= clock(t, ibyte, ibyte_valid);
    end if;
  end process;


  Receiver : process (clk) is
  begin
    if rising_edge(clk) then
      r <= clock(r, t.tx, obyte_ready);
    end if;
  end process;


  Main : process is
  begin
    wait for CLK_PERIOD;

    for i in idata'range loop
      ibyte <= idata(i);
      ibyte_valid <= '1';
      wait until rising_edge(clk) and ibyte_valid = '1' and t.ibyte_ready = '1';
      ibyte_valid <= '0';

      obyte_ready <= '1';
      wait until rising_edge(clk) and obyte_ready = '1' and r.obyte_valid = '1';
      odata(i) <= r.obyte;
    end loop;

    wait for CLK_PERIOD;

    for i in odata'range loop
      assert idata(i) = odata(i)
        report i'image & ": invalid data, got " & odata(i)'image & ", want " & idata(i)'image
        severity failure;
    end loop;

    std.env.finish;
  end process;

end architecture;