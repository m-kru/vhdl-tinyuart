-- SPDX-License-Identifier: MIT
-- https://github.com/m-kru/vhdl-tinyuart
-- Copyright (c) 2025 Michał Kruszewski

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.ceil;
  use ieee.math_real.log2;

package tinyuart is

  -- Internal state type for both transmitter and receiver.
  type state_t is (IDLE, TRANSMISSION);

  -- UART transmitter with the fixed 8N1 configuration:
  -- 8 - eight data bits
  -- N - no parity bit,
  -- 1 - one stop bit.
  --
  -- The user must provide the correct value for the CYCLES_PER_BAUD.
  -- Use the following calculation formula: (clock frequency) / (baudrate).
  type transmitter_t is record
    -- Configuration elements
    CYCLES_PER_BAUD : positive; -- Number of clock cycles per single baud
    REPORT_PREFIX   : string;   -- Optional prefix used in report messages
    -- Output elements
    ibyte_ready : std_logic; -- Input byte ready handshake signal
    tx : std_logic; -- Serial tx output
    -- Internal elements
    state   : state_t;
    byte    : std_logic_vector(7 downto 0); -- Byte latched for transmission
    cnt     : unsigned; -- General purpose counter
    bit_cnt : natural range 0 to 9; -- Bit counter
  end record;

  -- Initializes transmitter_t type.
  function init (
    -- Configuration elements
    CYCLES_PER_BAUD : positive;
    REPORT_PREFIX   : string := "tinyuart: transmitter: ";
    -- Output elements
    ibyte_ready : std_logic := '0';
    tx          : std_logic := '1';
    -- Internal elements
    state   : state_t := IDLE;
    byte    : std_logic_vector(7 downto 0) := (others => '-');
    cnt     : natural := 0;
    bit_cnt : natural := 0
  ) return transmitter_t;

  -- Clocks transmitter.
  function clock (
    transmitter : transmitter_t;
    ibyte       : std_logic_vector(7 downto 0); -- Input byte
    ibyte_valid : std_logic -- Input byte valid handshake signal
  ) return transmitter_t;

  -- UART receiver with the fixed 8N1 configuration:
  -- 8 - eight data bits
  -- N - no parity bit,
  -- 1 - one stop bit.
  --
  -- The user must provide the correct value for the CYCLES_PER_BAUD.
  -- Use the following calculation formula: (clock frequency) / (baudrate).
  --
  -- The stop_bit_err signals that sampled stop bit value was different than '1'.
  -- The signal is cleared after a successful output byte handshake.
  -- If you want to count the number of stop bit errors, then connect this signal
  -- to a rising edge detector and count the edges.
  type receiver_t is record
    -- Configuration elements
    CYCLES_PER_BAUD : positive; -- Number of clock cycles per single baud
    REPORT_PREFIX   : string;   -- Optional prefix used in report messages
    -- Output elements
    obyte        : std_logic_vector(7 downto 0); -- Output byte
    obyte_valid  : std_logic; -- Output byte valid handshake signal
    stop_bit_err : std_logic; -- Stop bit error
    -- Internal elements
    state   : state_t;
    cnt     : unsigned; -- General purpose counter
    bit_cnt : natural range 0 to 8; -- Bit counter
  end record;

  -- Initializes receiver_t type.
  function init (
    -- Configuration elements
    CYCLES_PER_BAUD : positive;
    REPORT_PREFIX   : string := "tinyuart: receiver: ";
    -- Output elements
    obyte        : std_logic_vector(7 downto 0) := (others => '-');
    obyte_valid  : std_logic := '0';
    stop_bit_err : std_logic := '0';
    -- Internal elements
    state   : state_t := IDLE;
    cnt     : natural := 0;
    bit_cnt : natural := 0
  ) return receiver_t;

  -- Clocks receiver.
  function clock (
    receiver    : receiver_t;
    rx          : std_logic; -- Serial rx input
    obyte_ready : std_logic  -- Output byte ready handshake signal
  ) return receiver_t;

end package;


package body tinyuart is

  -- Transmitter functions

  function init (
    CYCLES_PER_BAUD : positive;
    REPORT_PREFIX   : string := "tinyuart: transmitter: ";
    ibyte_ready : std_logic := '0';
    tx      : std_logic := '1';
    state   : state_t := IDLE;
    byte    : std_logic_vector(7 downto 0) := (others => '-');
    cnt     : natural := 0;
    bit_cnt : natural := 0
  ) return transmitter_t is
    constant CNT_WIDTH : natural := integer(ceil(log2(real(CYCLES_PER_BAUD))));
    constant t : transmitter_t := (
      CYCLES_PER_BAUD => CYCLES_PER_BAUD,
      REPORT_PREFIX   => REPORT_PREFIX,
      ibyte_ready     => ibyte_ready,
      state           => state,
      byte            => byte,
      tx              => tx,
      cnt             => to_unsigned(cnt, CNT_WIDTH),
      bit_cnt         => bit_cnt
    );
  begin return t; end function;


  function clock_idle (
    transmitter : transmitter_t;
    ibyte       : std_logic_vector(7 downto 0);
    ibyte_valid : std_logic
  ) return transmitter_t is
    variable t : transmitter_t := transmitter;
  begin
    t.cnt := to_unsigned(t.CYCLES_PER_BAUD, t.cnt'length);
    t.bit_cnt := 0;
    t.tx := '1';

    if t.ibyte_ready and ibyte_valid then
      report t.REPORT_PREFIX & "starting b""" & to_string(ibyte) & """ transmission";

      t.tx := '0'; -- Start bit
      t.ibyte_ready := '0';
      t.byte := ibyte;
      t.state := TRANSMISSION;
    else
      t.ibyte_ready := '1';
    end if;

    return t;
  end function;


  function clock_transmission (
    transmitter : transmitter_t
  ) return transmitter_t is
    variable t : transmitter_t := transmitter;
  begin
    if t.cnt = 0 then
      t.cnt := to_unsigned(t.CYCLES_PER_BAUD, t.cnt'length);


      if t.bit_cnt = 9 then
        report t.REPORT_PREFIX & " b""" &  to_string(t.byte) & """ transmission finished";
        t.state := IDLE;
      else
        if t.bit_cnt = 8 then
          t.tx := '1'; -- Stop bit
        else
          t.tx := t.byte(t.bit_cnt);
        end if;

        t.bit_cnt := t.bit_cnt + 1;
      end if;
    else
      t.cnt := t.cnt - 1;
    end if;

    return t;
  end function;


  function clock (
    transmitter : transmitter_t;
    ibyte       : std_logic_vector(7 downto 0);
    ibyte_valid : std_logic
  ) return transmitter_t is
    variable t : transmitter_t := transmitter;
  begin
    case t.state is
      when IDLE         => t := clock_idle         (t, ibyte, ibyte_valid);
      when TRANSMISSION => t := clock_transmission (t);
    end case;
    return t;
  end function;


  -- Receiver functions

  -- Initializes receiver_t type.
  function init (
    -- Configuration elements
    CYCLES_PER_BAUD : positive;
    REPORT_PREFIX   : string := "tinyuart: receiver: ";
    -- Output elements
    obyte        : std_logic_vector(7 downto 0) := (others => '-');
    obyte_valid  : std_logic := '0';
    stop_bit_err : std_logic := '0';
    -- Internal elements
    state   : state_t := IDLE;
    cnt     : natural := 0;
    bit_cnt : natural := 0
  ) return receiver_t is
    constant CNT_WIDTH : natural := integer(ceil(log2(real(CYCLES_PER_BAUD + CYCLES_PER_BAUD/2))));
    constant r : receiver_t := (
      CYCLES_PER_BAUD => CYCLES_PER_BAUD,
      REPORT_PREFIX   => REPORT_PREFIX,
      obyte           => obyte,
      obyte_valid     => obyte_valid,
      stop_bit_err    => stop_bit_err,
      state           => state,
      cnt             => to_unsigned(cnt, CNT_WIDTH),
      bit_cnt         => bit_cnt
    );
  begin return r; end function;


  function clock_idle (
    receiver    : receiver_t;
    rx          : std_logic
  ) return receiver_t is
    variable r : receiver_t := receiver;
  begin
    r.obyte_valid := '0';
    r.stop_bit_err := '0';
    r.cnt := to_unsigned(r.CYCLES_PER_BAUD + r.CYCLES_PER_BAUD/2, r.cnt'length);
    r.bit_cnt := 0;

    if rx = '0' then
      report r.REPORT_PREFIX & "starting reception";
      r.state := TRANSMISSION;
    end if;

    return r;
  end function;


  function clock_transmission (
    receiver    : receiver_t;
    rx          : std_logic;
    obyte_ready : std_logic
  ) return receiver_t is
    variable r : receiver_t := receiver;
  begin
    if r.obyte_valid and obyte_ready then
      r.obyte_valid := '0';
      r.state := IDLE;
    else
      if r.cnt = 0 then
        if r.bit_cnt = 8 then
          report r.REPORT_PREFIX & "received b""" & to_string(r.obyte) & """, stop bit '" & to_string(rx) & "'";

          if rx = '0' then
            r.stop_bit_err := '1';
          end if;
          r.obyte_valid := '1';
        else
          r.obyte(r.bit_cnt) := rx;
          r.bit_cnt := r.bit_cnt + 1;
        end if;

        r.cnt := to_unsigned(r.CYCLES_PER_BAUD, r.cnt'length);
      else
        r.cnt := r.cnt - 1;
      end if;
    end if;

    return r;
  end function;


  function clock (
    receiver    : receiver_t;
    rx          : std_logic;
    obyte_ready : std_logic
  ) return receiver_t is
    variable r : receiver_t := receiver;
  begin
    case r.state is
      when IDLE         => r := clock_idle         (r, rx);
      when TRANSMISSION => r := clock_transmission (r, rx, obyte_ready);
    end case;
    return r;
  end function;

end package body;
