# StandardStaking

/*[ ![Codeship Status for ConsenSys/StandardBounties](https://app.codeship.com/projects/1e2726c0-ac83-0135-5579-52b4614bface/status?branch=master)](https://app.codeship.com/projects/257018)*/

`Version 0.1`

A set of contracts for people to open stakes, and allow people to claim against them.

1. [Rationale](#1-rationale)
2. [Implementation](#2-implementation)
3. [Development](#3-development)
4. [Documentation](#4-documentation)

## 1. Rationale

Bounties are the simplest form of an incentive mechanism: giving people tokens for completing a task. The Ethereum blockchain provides a number of benefits to support these incentive mechanisms:
- The ability to inexpensively transact with individuals from across the world
- The ability to lock up funds in an escrow contract (a bounty) which disburses funds when a proof of task completion or deliverable is accepted
- The ability to host these bounties in an open and interoperable manner, so that many different types of applications can be used to create, explore, and complete bounties from a shared liquidity pool (that no one controls)
In this way, StandardBounties enables teams to create bounties through one application (like their DAO), and instantly have the bounty be listed on several bounty marketplaces at once, maximizing the bounty's reach and making the markets more efficient.


## 2. Implementation
There are several key types of users within a bounty:
- `Bounty Issuers` are a list of addresses who have the power to drain the bounty and edit the details associated with the bounty.
- `Bounty Approvers` are a list of addresses who have the power to accept submissions which are made to the bounty. (*Note: Issuers are not assumed to also be approvers, but may add themselves as such if desired*)
- `Bounty Contributors` are any address which has made a contribution to a given bounty
- `Bounty Fulfillers` are any addresses which are included as contributors to any submission made to a given bounty
- `Bounty Submitters` are any addresses which submit fulfillments, either on their own behalf or for other people

Together, these actors coordinate to deploy capital and shape human behavior with the power of incentives.

There are several core actions in the lifecycle of a bounty, which can be performed by certain users:
- *Anyone* may `issue` a bounty, specifying the details of the bounty and anchoring the associated IPFS hash on-chain within the StandardBounties smart contract
- *Anyone* may `contribute` to a bounty, specifying the amount of tokens they'd like to add to the port.
- *Anyone* may `fulfill` a bounty, submitting a list of contributors and an IPFS hash of the details and deliverables.
- *Any of the Bounty's Approvers* may `accept` a fulfillment, submitting the amount of tokens they'd like each contributor to receive.

These actions make up the core life cycle of a bounty, supporting funds flowing into various bounties, and subsequently flowing out as tasks are completed.

There are several additional actions which various users may perform:
- *Any Contributor* may refund their contributions to a bounty, so long as the deadline of the bounty has elapsed and no submissions were accepted.
- *Any Issuer* may refund the contributions of other users if they wish (even if the deadline hasn't elapsed or the bounty has paid out a subset of funds)
- *Any Issuer* may drain the bounty of a subset of the funds in the bounty
- *Anyone* may perform a generalized `action`, submitting the IPFS hash which stores the details of their action (ie commenting, submitting their intention to complete the bounty, etc)
- *Any Submitter* can update their submission, making changes to the submission data or the list of Contributors
- *Any Approver* may simultaneously submit an off-chain fulfillment and accept it, immutably recording the exchange while saving the need to preemptively submit the fulfillments on-chain
- *Any Issuer* may change any of the details of the bounty, *except for the token contract associated with the bounty which may not be changed*.

Alongside the ability to perform any of these actions natively within the StandardBounties contract, we've also deployed a MetaTransactionRelayer contract which decodes signed messages for users and performs actions on their behalf, so that they aren't required to pay gas fees.

## 3. Development

Any application can take advantage of the Bounties Network registry, which is currently deployed on both the Main Ethereum Network and the Rinkeby Testnet.

- On Mainnet, the StandardBounties contract is deployed at `0xa7135d0a62939501b5304a04bf00d1a9a22f6623`, and the BountiesMetaTxRelayer is deployed at `0xf7fc27202bc20ce95ef28340d8e542346cb56b6d`

- On Rinkeby, the StandardBounties contract is deployed at `0x1ca6b906917167366324aed6c6a708131136bea9`, and the BountiesMetaTxRelayer is deployed at `0x70a1cd9b015253129b11ec9166beae620140b29d`

## 4. Documentation

For thorough documentation of all functionality, see [the documentation](./docs/documentation_v2.3.md)
