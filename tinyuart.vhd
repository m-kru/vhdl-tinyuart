-- SPDX-License-Identifier: MIT
-- https://github.com/m-kru/vhdl-tinyuart
-- Copyright (c) 2025 Michał Kruszewski

library ieee;
  use ieee.std_logic_1164.all;

package tinyuart is

  -- Internal state type for both transmitter and receiver.
  type state_t is (IDLE, TRANSMISSION);

  -- UART transmitter with the fixed 8N1 configuration:
  -- 8 - eight data bits
  -- N - no parity bit,
  -- 1 - one stop bit.
  type transmitter_t is record
    -- Configuration elements
    CYCLES_PER_BAUD : positive; -- Number of clock cycles per single baud
    PREFIX : string; -- Optional prefix used in report messages
    -- Output elements
    byte_in_ready : std_logic;
    tx : std_logic; -- Serial tx output
    -- Internal elements
    state   : state_t;
    byte    : std_logic_vector(7 downto 0); -- Byte latched for transmission
    cnt     : natural; -- General purpose counter
    bit_cnt : natural range 0 to 9: -- Bit counter
  end record;

  -- Initializes transmitter_t type.
  function init (
    CYCLES_PER_BAUD : positive;
    PREFIX          : string := "tinyuart: transmitter: ";
    byte_in_ready   : std_logic := '0';
    tx      : std_logic := '-';
    state   : state_t := IDLE;
    byte    : std_logic_vector(7 downto 0) := (others => '-');
    cnt     : natural := 0;
    bit_cnt : natural := 0
  ) return transmitter_t;

  function clock (
    transmitter   : trnamistter_t;
    byte_in       : std_logic_vector(7 downto 0);
    byte_in_valid : std_logic
  ) return transmitter_t;

end package;


package body tinyuart is

  -- Transmitter functions

  function init (
    CYCLES_PER_BAUD : positive;
    PREFIX          : string := "tinyuart: transmitter: ";
    byte_in_ready   : std_logic := '0';
    state   : state_t := IDLE;
    byte    : std_logic_vector(7 downto 0) := (others => '-');
    tx      : std_logic := '-';
    cnt     : natural := 0;
    bit_cnt : natural := 0
  ) return transmitter_t is
    constant t := transmitter_t (
      CYCLES_PER_BAUD => CYCLES_PER_BAUD,
      byte_in_ready   => byte_in_ready,
      state           => state,
      byte            => byte,
      tx              => tx,
      cnt             => cnt,
      bit_cnt         => bit_cnt
    );
  begin
    return t;
  end function;


  function clock_idle (
    transmitter   : trnamistter_t;
    byte_in       : std_logic_vector(7 downto 0);
    byte_in_valid : std_logic
  ) return transmitter_ is
    variable t : transmitter_t := transmitter;
  begin
    t.cnt := t.CYCLES_PER_BAUD;
    t.bit_cnt := 9;

    if t.byte_in_ready and byte_in_valid then
      t.tx := '0'; -- Generate start bit
      t.byte_in_ready := '0';
      t.state := TRANSMISSION;
    else
      t.byte_in_ready := '1';
    end if;

    return t;
  end function;


  function clock_transmission (
    transmitter   : trnamistter_t
  ) return transmitter_t is
    variable t : transmitter_t := transmitter;
  begin
    if t.cnt = 0 then
      t.cnt := t.CYCLES_PER_BAUD;

      if t.bit_cnt = 0 then
        t.state := IDLE;
      else
        t.bit_cnt := t.bit_cnt - 1;

        if t.bit_cnt == 0 then
          t.tx := '1'; -- Stop bit
        else
          t.tx := t.byte(bit_cnt-1);
        end if;
      end if;
    else
      t.cnt := t.cnt - 1;
    end if;

    return t;
  end function;


  function clock (
    transmitter   : trnamistter_t;
    byte_in       : std_logic_vector(7 downto 0);
    byte_in_valid : std_logic
  ) return transmitter_ is
    variable t : transmitter_t := transmitter;
  begin
    case t.state is
    when IDLE         => clock_idle         (t, byte_in, byte_in_valid);
    when TRANSMISSION => clock_transmission (t);
    when others => report "unimplemented state " & state_t'image(t.state) severity failure;
    end case;
    return t;
  end function;


  -- Receiver functions

end package body;