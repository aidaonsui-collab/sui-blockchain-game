module shrooms_token::shrooms_token {
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::balance::{Self, Balance};
    use sui::tx_context::TxContext;
    use sui::object::UID;
    use sui::transfer;
    use sui::sui::SUI;  // Added SUI type import


    // Error codes
    const ENotEnoughPayment: u64 = 0;
    const ENotAuthorized: u64 = 1;
    const ETooEarly: u64 = 3;


    /// Coin representing the $SHROOMS token
    public struct SHROOMS_TOKEN has drop {}

    /// Game state holding all farms and treasury
    public struct GameState has key {
        id: UID,
        treasury_cap: TreasuryCap<SHROOMS_TOKEN>,
        farms: vector<Farm>,
        total_farms: u64,
        total_shrooms_minted: u64,
        fee_balance: Balance<SUI>,
        dev_wallet: address,
    }

    /// Individual farm owned by a player
    public struct Farm has store {
        id: u64,
        owner: address,
        mushrooms: u64,
        level: u64,
        last_harvest_epoch: u64,
        created_at_epoch: u64,
    }

    // Constants
    const FARM_COST: u64 = 10_000_000_000; // 10 SUI
    const INITIAL_MUSHROOMS: u64 = 10;
    const UPGRADE_COST: u64 = 5_000_000_000; // 5 SUI

    /// Initialize the game and create the $SHROOMS token
    fun init(witness: SHROOMS_TOKEN, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency(
            witness,
            6, // decimals
            b"SHROOMS",
            b"Shrooms Token",
            b"Farm mushrooms, harvest $SHROOMS tokens on Sui blockchain",
            option::none(),
            ctx
        );

        transfer::public_freeze_object(metadata);

        let game_state = GameState {
            id: object::new(ctx),
            treasury_cap,
            farms: vector::empty(),
            total_farms: 0,
            total_shrooms_minted: 0,
            fee_balance: balance::zero(),
            dev_wallet: tx_context::sender(ctx),
        };

        transfer::share_object(game_state);
    }

    /// Mint initial tokens for DEX liquidity (dev only)
    public entry fun mint_for_liquidity(
        game_state: &mut GameState,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == game_state.dev_wallet, ENotAuthorized);
        
        let minted_coin = coin::mint(&mut game_state.treasury_cap, amount, ctx);
        transfer::public_transfer(minted_coin, recipient);
        game_state.total_shrooms_minted = game_state.total_shrooms_minted + amount;
    }

    /// Create a new farm
    public entry fun create_farm(
        game_state: &mut GameState,
        payment: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        assert!(coin::value(&payment) >= FARM_COST, ENotEnoughPayment);

        let payment_balance = coin::into_balance(payment);
        balance::join(&mut game_state.fee_balance, payment_balance);

        let farm = Farm {
            id: game_state.total_farms,
            owner: tx_context::sender(ctx),
            mushrooms: INITIAL_MUSHROOMS,
            level: 1,
            last_harvest_epoch: tx_context::epoch(ctx),
            created_at_epoch: tx_context::epoch(ctx),
        };

        vector::push_back(&mut game_state.farms, farm);
        game_state.total_farms = game_state.total_farms + 1;
    }

    /// Harvest $SHROOMS tokens from a farm
    public entry fun harvest(
        game_state: &mut GameState,
        farm_id: u64,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let current_epoch = tx_context::epoch(ctx);
        
        let farm_ref = vector::borrow_mut(&mut game_state.farms, farm_id);
        assert!(farm_ref.owner == sender, ENotAuthorized);

        let epochs_passed = current_epoch - farm_ref.last_harvest_epoch;
        assert!(epochs_passed > 0, ETooEarly);

        let yield_amount = calculate_yield(
            farm_ref.mushrooms,
            epochs_passed,
            farm_ref.level
        );

        let minted_coin = coin::mint(&mut game_state.treasury_cap, yield_amount, ctx);
        transfer::public_transfer(minted_coin, sender);

        farm_ref.last_harvest_epoch = current_epoch;
        game_state.total_shrooms_minted = game_state.total_shrooms_minted + yield_amount;
    }

    /// Calculate yield based on mushrooms, epochs, and level
    fun calculate_yield(mushrooms: u64, epochs: u64, level: u64): u64 {
        let base_yield = mushrooms * epochs * level;
        (base_yield * 5) / 100 // 0.05 multiplier
    }

    /// Plant more mushrooms on a farm
    public entry fun plant_mushrooms(
        game_state: &mut GameState,
        farm_id: u64,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let farm_ref = vector::borrow_mut(&mut game_state.farms, farm_id);
        assert!(farm_ref.owner == tx_context::sender(ctx), ENotAuthorized);
        farm_ref.mushrooms = farm_ref.mushrooms + amount;
    }

    /// Upgrade a farm to increase yield multiplier
    public entry fun upgrade_farm(
        game_state: &mut GameState,
        payment: Coin<SUI>,
        farm_id: u64,
        ctx: &mut TxContext
    ) {
        assert!(coin::value(&payment) >= UPGRADE_COST, ENotEnoughPayment);

        let payment_balance = coin::into_balance(payment);
        balance::join(&mut game_state.fee_balance, payment_balance);

        let farm_ref = vector::borrow_mut(&mut game_state.farms, farm_id);
        assert!(farm_ref.owner == tx_context::sender(ctx), ENotAuthorized);
        
        farm_ref.level = farm_ref.level + 1;
    }

    /// Withdraw accumulated fees (dev only)
    public entry fun withdraw_fees(
        game_state: &mut GameState,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == game_state.dev_wallet, ENotAuthorized);
        
        let amount = balance::value(&game_state.fee_balance);
        let withdrawn = coin::take(&mut game_state.fee_balance, amount, ctx);
        transfer::public_transfer(withdrawn, game_state.dev_wallet);
    }

    /// View functions
    public fun get_farm_info(game_state: &GameState, farm_id: u64): (address, u64, u64, u64, u64) {
        let farm = vector::borrow(&game_state.farms, farm_id);
        (farm.owner, farm.mushrooms, farm.level, farm.last_harvest_epoch, farm.created_at_epoch)
    }

    public fun get_game_stats(game_state: &GameState): (u64, u64, u64) {
        (game_state.total_farms, game_state.total_shrooms_minted, balance::value(&game_state.fee_balance))
    }
}
