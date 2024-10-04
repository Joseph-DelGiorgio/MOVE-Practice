module 0x0::PTB_Demo {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin, TreasuryCap};
    use std::option::{Self, Option};

    struct Position has key, store {
        id: UID,
        amount: u64,
    }

    struct ReferralTicket has store, drop {
        discount: u64,
    }

    struct PTB_DEMO has drop {}

    struct PTBTreasury has key {
        id: UID,
        treasury_cap: TreasuryCap<PTB_DEMO>,
    }

    fun init(witness: PTB_DEMO, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency(
            witness,
            9,
            b"PTB",
            b"PTB Coin",
            b"Demo coin for PTB",
            option::none(),
            ctx
        );
        transfer::public_transfer(metadata, tx_context::sender(ctx));
        
        let treasury = PTBTreasury {
            id: object::new(ctx),
            treasury_cap,
        };
        transfer::share_object(treasury);
    }

    public fun create_position(ctx: &mut TxContext) {
        let position = Position {
            id: object::new(ctx),
            amount: 0,
        };
        transfer::public_transfer(position, tx_context::sender(ctx));
    }

    public fun unstake(position: &mut Position) {
        position.amount = 0;
    }

    public fun claim_referral_ticket(): ReferralTicket {
        ReferralTicket { discount: 10 }
    }

    public fun borrow_with_referral(
        position: &mut Position,
        ticket: ReferralTicket,
        amount: u64,
        treasury: &mut PTBTreasury,
        ctx: &mut TxContext
    ): Coin<PTB_DEMO> {
        let ReferralTicket { discount: _ } = ticket;
        position.amount = position.amount + amount;
        coin::mint(&mut treasury.treasury_cap, amount, ctx)
    }

    public fun stake(position: &mut Position, amount: u64) {
        position.amount = position.amount + amount;
    }

    public entry fun perform_complex_operation(
        position: &mut Position,
        amount: u64,
        treasury: &mut PTBTreasury,
        ctx: &mut TxContext
    ) {
        unstake(position);
        let ticket = claim_referral_ticket();
        let borrowed_coins = borrow_with_referral(position, ticket, amount, treasury, ctx);
        transfer::public_transfer(borrowed_coins, tx_context::sender(ctx));
        stake(position, amount);
    }
}

//Typescript
import { TransactionBlock } from '@mysten/sui.js/transactions';
import { SuiClient } from '@mysten/sui.js/client';
import { Ed25519Keypair } from '@mysten/sui.js/keypairs/ed25519';

// Initialize the Sui client
const client = new SuiClient({ url: 'https://fullnode.devnet.sui.io' });

// Create a new transaction block
const txb = new TransactionBlock();

// Use the actual package ID from your deployed contract
const packageId = '0x9dd5e0905d4cd0733c9d5d11ff564d521a6ac6f2a36151dd8a49aaee182177fc';

// Use the actual treasury ID from your deployed contract
const treasuryId = '0x8ba3807b2bfefce96a7ca03a5d29abfbc12deacecf2016e5fadfcd34e8c7bd94';

// Step 1: Create a new position
const newPosition = txb.moveCall({
  target: `${packageId}::PTB_Demo::create_position`,
});

// Step 2: Claim a referral ticket
const referralTicket = txb.moveCall({
  target: `${packageId}::PTB_Demo::claim_referral_ticket`,
});

// Step 3: Borrow with referral
const amount = 1000; // Example amount
const borrowedCoins = txb.moveCall({
  target: `${packageId}::PTB_Demo::borrow_with_referral`,
  arguments: [
    newPosition,
    referralTicket,
    txb.pure(amount),
    txb.object(treasuryId),
  ],
});

// Step 4: Stake the borrowed amount
txb.moveCall({
  target: `${packageId}::PTB_Demo::stake`,
  arguments: [newPosition, txb.pure(amount)],
});

// Execute the transaction block
async function executeTransaction(signer: Ed25519Keypair) {
  try {
    const result = await client.signAndExecuteTransactionBlock({
      signer,
      transactionBlock: txb,
    });
    console.log('Transaction executed successfully:', result);
  } catch (error) {
    console.error('Error executing transaction:', error);
  }
}

// To execute the transaction, uncomment and provide a valid keypair:
// const keypair = new Ed25519Keypair();
// executeTransaction(keypair);


