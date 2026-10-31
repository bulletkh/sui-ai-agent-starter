// Copyright (c) SUI World Research
// SPDX-License-Identifier: Apache-2.0

/// Module defining the apex DeFAI native token `$AGENT` on Sui Move 2024.
/// Designed for autonomous liquidity, agent treasury management, and PTB execution.
module sui_ai_agent_starter::agent {
    use sui::coin::{Self, TreasuryCap};
    use sui::url;

    /// One-Time Witness for the AGENT coin.
    public struct AGENT has drop {}

    /// Initialize the AGENT currency.
    /// Creates the currency with 9 decimals and freezes metadata.
    fun init(witness: AGENT, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency(
            witness,
            9, // Standard Sui decimals
            b"AGENT",
            b"Sui Agent",
            b"The flagship DeFAI autonomous agent token on Sui Move 2024. Powered by SpendingLimitCap and atomic PTB execution.",
            option::some(url::new_unsafe_from_bytes(b"https://github.com/bulletkh/sui-ai-agent-starter")),
            ctx,
        );

        // Metadata is immutable and permanently verified
        transfer::public_freeze_object(metadata);

        // TreasuryCap transferred to the deployer for initial liquidity pool provisioning
        transfer::public_transfer(treasury_cap, ctx.sender());
    }

    /// Mint new AGENT tokens (restricted to TreasuryCap holder)
    public entry fun mint(
        treasury_cap: &mut TreasuryCap<AGENT>,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        let coin = coin::mint(treasury_cap, amount, ctx);
        transfer::public_transfer(coin, recipient);
    }

    /// Burn AGENT tokens to enforce autonomous deflation from agent trading profits
    public entry fun burn(
        treasury_cap: &mut TreasuryCap<AGENT>,
        coin: coin::Coin<AGENT>,
    ) {
        coin::burn(treasury_cap, coin);
    }
}
