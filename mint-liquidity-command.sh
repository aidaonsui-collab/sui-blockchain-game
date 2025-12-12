#!/bin/bash

# Mint 10,000,000 SHROOMS tokens for DEX liquidity
sui client call \
  --package 0x1ae8ae59af497b5b1d5f6ad51f2fb6e6c6043563598dbc3ea3ded7d1b4965b03 \
  --module shrooms_token \
  --function mint_for_liquidity \
  --args 0x42d2e40905a712c726c478c5db350c0ee16232e74e497661c102f4883bf7fd51 10000000000000 0x2c478b5f158e037cb21b3443a5a3512f6fee0b9a16d7a261baa00ddca69d6fc5 \
  --gas-budget 10000000
