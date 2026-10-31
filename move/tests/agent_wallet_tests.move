#[test_only]
module sui_ai_agent_starter::agent_wallet_tests {
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui_ai_agent_starter::agent_wallet::{
        Self,
        AgentWallet,
        AdminCap,
        AgentCap
    };

    const ADMIN: address = @0xAD;
    const AGENT: address = @0xBA5E;

    fun setup_test(scenario: &mut Scenario) {
        ts::next_tx(scenario, ADMIN);
        {
            let ctx = ts::ctx(scenario);
            let initial_coin = coin::mint_for_testing<SUI>(1_000_000, ctx);
            agent_wallet::create_wallet<SUI>(
                initial_coin,
                100_000, // Daily limit: 100k
                AGENT,
                ctx
            );
        };
    }

    #[test]
    fun test_create_and_spend_within_limit() {
        let mut scenario = ts::begin(ADMIN);
        setup_test(&mut scenario);

        // Agent executes valid spend
        ts::next_tx(&mut scenario, AGENT);
        {
            let mut wallet = ts::take_shared<AgentWallet<SUI>>(&scenario);
            let agent_cap = ts::take_from_sender<AgentCap>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            assert!(agent_wallet::remaining_budget(&wallet) == 100_000, 0);

            let spent_coin = agent_wallet::spend<SUI>(
                &mut wallet,
                &agent_cap,
                40_000,
                ctx
            );

            assert!(coin::value(&spent_coin) == 40_000, 1);
            assert!(agent_wallet::remaining_budget(&wallet) == 60_000, 2);
            assert!(agent_wallet::balance_value(&wallet) == 960_000, 3);

            coin::burn_for_testing(spent_coin);
            ts::return_shared(wallet);
            ts::return_to_sender(&scenario, agent_cap);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = agent_wallet::ESpendingLimitExceeded)]
    fun test_spend_exceeds_limit() {
        let mut scenario = ts::begin(ADMIN);
        setup_test(&mut scenario);

        ts::next_tx(&mut scenario, AGENT);
        {
            let mut wallet = ts::take_shared<AgentWallet<SUI>>(&scenario);
            let agent_cap = ts::take_from_sender<AgentCap>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            // Attempt to spend 150k when limit is 100k -> should abort
            let spent_coin = agent_wallet::spend<SUI>(
                &mut wallet,
                &agent_cap,
                150_000,
                ctx
            );

            coin::burn_for_testing(spent_coin);
            ts::return_shared(wallet);
            ts::return_to_sender(&scenario, agent_cap);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = agent_wallet::EWalletHalted)]
    fun test_emergency_halt_blocks_spend() {
        let mut scenario = ts::begin(ADMIN);
        setup_test(&mut scenario);

        // Admin triggers emergency halt
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut wallet = ts::take_shared<AgentWallet<SUI>>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            agent_wallet::toggle_emergency_halt<SUI>(&mut wallet, &admin_cap, true, ctx);
            assert!(agent_wallet::is_halted(&wallet), 4);

            ts::return_shared(wallet);
            ts::return_to_sender(&scenario, admin_cap);
        };

        // Agent tries to spend during halt -> abort
        ts::next_tx(&mut scenario, AGENT);
        {
            let mut wallet = ts::take_shared<AgentWallet<SUI>>(&scenario);
            let agent_cap = ts::take_from_sender<AgentCap>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            let spent_coin = agent_wallet::spend<SUI>(
                &mut wallet,
                &agent_cap,
                10_000,
                ctx
            );

            coin::burn_for_testing(spent_coin);
            ts::return_shared(wallet);
            ts::return_to_sender(&scenario, agent_cap);
        };

        ts::end(scenario);
    }
}
