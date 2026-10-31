// Copyright (c) SUI World Research
// SPDX-License-Identifier: Apache-2.0

module sui_ai_agent_starter::agent_wallet {
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::event;

    // Error Codes
    const ESpendingLimitExceeded: u64 = 1;
    const EWalletHalted: u64 = 2;
    const EInvalidAgentCap: u64 = 3;
    const EInsufficientFunds: u64 = 4;
    const EZeroAmount: u64 = 5;

    // =========================================================================
    // EVENTS
    // =========================================================================

    public struct AgentWalletCreated has copy, drop {
        wallet_id: ID,
        admin: address,
        agent_id: address,
        daily_limit: u64,
    }

    public struct ActionExecuted has copy, drop {
        wallet_id: ID,
        amount: u64,
        remaining_budget: u64,
        recipient: address,
        epoch: u64,
    }

    public struct BudgetRefilled has copy, drop {
        wallet_id: ID,
        new_budget: u64,
        epoch: u64,
    }

    public struct EmergencyHaltToggled has copy, drop {
        wallet_id: ID,
        is_halted: bool,
    }

    public struct SpendingLimitUpdated has copy, drop {
        wallet_id: ID,
        old_limit: u64,
        new_limit: u64,
    }

    // =========================================================================
    // CAPABILITIES & OBJECTS
    // =========================================================================

    /// Admin capability granting master custody and parameter configuration.
    public struct AdminCap has key, store {
        id: UID,
        wallet_id: ID,
    }

    /// Agent capability held by the autonomous AI runtime to execute authorized transactions.
    public struct AgentCap has key, store {
        id: UID,
        wallet_id: ID,
    }

    /// Shared autonomous treasury object.
    public struct AgentWallet<phantom T> has key {
        id: UID,
        balance: Balance<T>,
        daily_limit: u64,
        spent_this_epoch: u64,
        last_refill_epoch: u64,
        is_halted: bool,
    }

    /// Creates a new AgentWallet treasury with an AdminCap and an AgentCap.
    #[allow(lint(self_transfer))]
    public fun create_wallet<T>(
        initial_funds: Coin<T>,
        daily_limit: u64,
        agent_recipient: address,
        ctx: &mut TxContext
    ) {
        let wallet_uid = object::new(ctx);
        let wallet_id = object::uid_to_inner(&wallet_uid);
        let admin = ctx.sender();

        let wallet = AgentWallet<T> {
            id: wallet_uid,
            balance: coin::into_balance(initial_funds),
            daily_limit,
            spent_this_epoch: 0,
            last_refill_epoch: ctx.epoch(),
            is_halted: false,
        };

        let admin_cap = AdminCap {
            id: object::new(ctx),
            wallet_id,
        };

        let agent_cap = AgentCap {
            id: object::new(ctx),
            wallet_id,
        };

        event::emit(AgentWalletCreated {
            wallet_id,
            admin,
            agent_id: agent_recipient,
            daily_limit,
        });

        transfer::public_transfer(admin_cap, admin);
        transfer::public_transfer(agent_cap, agent_recipient);
        transfer::share_object(wallet);
    }

    /// Autonomous spend invoked by the AI Agent holding AgentCap.
    /// Returns extracted Coin<T> for atomic PTB chaining (e.g. Swaps, LPs, Flash-loans).
    public fun spend<T>(
        wallet: &mut AgentWallet<T>,
        cap: &AgentCap,
        amount: u64,
        ctx: &mut TxContext
    ): Coin<T> {
        assert!(!wallet.is_halted, EWalletHalted);
        assert!(cap.wallet_id == object::id(wallet), EInvalidAgentCap);
        assert!(amount > 0, EZeroAmount);

        let current_epoch = ctx.epoch();

        // Auto-refill budget if a new epoch has started
        if (current_epoch > wallet.last_refill_epoch) {
            wallet.spent_this_epoch = 0;
            wallet.last_refill_epoch = current_epoch;
            event::emit(BudgetRefilled {
                wallet_id: object::id(wallet),
                new_budget: wallet.daily_limit,
                epoch: current_epoch,
            });
        };

        // Enforce spending limit
        assert!(wallet.spent_this_epoch + amount <= wallet.daily_limit, ESpendingLimitExceeded);
        assert!(balance::value(&wallet.balance) >= amount, EInsufficientFunds);

        wallet.spent_this_epoch = wallet.spent_this_epoch + amount;

        let extracted_balance = balance::split(&mut wallet.balance, amount);
        let extracted_coin = coin::from_balance(extracted_balance, ctx);

        let remaining_budget = wallet.daily_limit - wallet.spent_this_epoch;

        event::emit(ActionExecuted {
            wallet_id: object::id(wallet),
            amount,
            remaining_budget,
            recipient: ctx.sender(),
            epoch: current_epoch,
        });

        extracted_coin
    }

    /// Deposit additional funds into the AgentWallet treasury.
    public fun deposit<T>(
        wallet: &mut AgentWallet<T>,
        funds: Coin<T>,
        _ctx: &mut TxContext
    ) {
        coin::put(&mut wallet.balance, funds);
    }

    // =========================================================================
    // ADMIN FUNCTIONS (Human Supervision)
    // =========================================================================

    /// Emergency switch: Freeze/unfreeze agent execution immediately.
    public fun toggle_emergency_halt<T>(
        wallet: &mut AgentWallet<T>,
        cap: &AdminCap,
        halt: bool,
        _ctx: &mut TxContext
    ) {
        assert!(cap.wallet_id == object::id(wallet), EInvalidAgentCap);
        wallet.is_halted = halt;
        event::emit(EmergencyHaltToggled {
            wallet_id: object::id(wallet),
            is_halted: halt,
        });
    }

    /// Update the daily spending limit.
    public fun set_daily_limit<T>(
        wallet: &mut AgentWallet<T>,
        cap: &AdminCap,
        new_limit: u64,
        _ctx: &mut TxContext
    ) {
        assert!(cap.wallet_id == object::id(wallet), EInvalidAgentCap);
        let old_limit = wallet.daily_limit;
        wallet.daily_limit = new_limit;
        event::emit(SpendingLimitUpdated {
            wallet_id: object::id(wallet),
            old_limit,
            new_limit,
        });
    }

    /// Admin master withdrawal: sweep any amount of funds to safety.
    public fun admin_withdraw<T>(
        wallet: &mut AgentWallet<T>,
        cap: &AdminCap,
        amount: u64,
        ctx: &mut TxContext
    ): Coin<T> {
        assert!(cap.wallet_id == object::id(wallet), EInvalidAgentCap);
        assert!(balance::value(&wallet.balance) >= amount, EInsufficientFunds);

        let extracted = balance::split(&mut wallet.balance, amount);
        coin::from_balance(extracted, ctx)
    }

    // =========================================================================
    // VIEW FUNCTIONS
    // =========================================================================

    public fun balance_value<T>(wallet: &AgentWallet<T>): u64 {
        balance::value(&wallet.balance)
    }

    public fun daily_limit<T>(wallet: &AgentWallet<T>): u64 {
        wallet.daily_limit
    }

    public fun remaining_budget<T>(wallet: &AgentWallet<T>): u64 {
        if (wallet.daily_limit >= wallet.spent_this_epoch) {
            wallet.daily_limit - wallet.spent_this_epoch
        } else {
            0
        }
    }

    public fun is_halted<T>(wallet: &AgentWallet<T>): bool {
        wallet.is_halted
    }
}
