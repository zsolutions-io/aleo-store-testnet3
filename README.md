# Aleo.store NFT Standard

Marketplace and standard proposition for NFTs on Aleo. Detailed documentation for the program can be found [here](https://docs.aleo.store).

[A demo video is also available.](https://www.youtube.com/watch?v=I-JNPbK0-Qk)

__Official marketplace frontend:__ [Aleo.store](https://aleo.store)

__Program ID:__ `aleo_store_nft.aleo`

# Project Description

Aleo.store is a program that allows users to create and sell NFTs on the Aleo Blockchain. It is a standard proposition for collections and NFTs on Aleo, a marketplace, and an address Alias registry.

It comes with a frontend that enable users to fully interact with the program, create their own collections, NFTs as well as Aliases and to sell them to each other, or provide zero knowledge proofs of their content.

# Build Guide

To compile this program, run:

```bash
leo build
```

To execute this program, run:

```bash
leo run
```

To deploy this program, run:

```bash
API="https://vm.aleo.org/api"
BROADCAST="testnet3/transaction/broadcast"
APPNAME="REPLACE_HERE_APPNAME"
PRIVATEKEY="REPLACE_HERE_PRIVATEKEY"
RECORD="REPLACE_HERE_FEE_RECORD"

snarkos developer deploy \
"${APPNAME}.aleo" \
--private-key "${PRIVATEKEY}" \
--query "${API}" \
--path "./build/" \
--broadcast "${API}/${BROADCAST}" \
--fee 0 \
--record "${RECORD}"
```

# Program Transitions documentation

## NFT standard

### Lifecycle Overview

![Aleo store token lifecycle](images/aleo_life_cycle.png?raw=true "Aleo store token lifecycle")

### Concepts

#### Collection

##### Definition

A `Collection` is a record that is a prerequisite to create and manage `Token` objects, defined as such:

```rust
record Collection {
    owner: address,
    id: CollectionId,
    data: CollectionData
}
```

Ownership of collection record grants authority over updating collection data, minting/burning its tokens and managing its public mints.
Every Collection has a unique identifier:

```rust
struct CollectionId {
    collection_number: u128
}
```

And associated private data:

```rust
struct CollectionData {
    updatable: bool
}
```

__Attributes__:

- `updatable (bool)`: wether collection Tokens can be burned or not and wether their `token_data (TokenData)` can be updated or not.

#### CollectionPublicData and uniqueness

A Collection always has public data associated with it:

```rust
struct CollectionPublicData {
    royalty_fees: u64,
    royalty_address: address,
    metadata_uri: String64,
    base_uri: String64,
    publicizable: bool
}
```

__Attributes__:

- `royalty_fees (u64)`: Permyriad of the price sent to creator when `Token` objects belonging to `Collection` are sold (100 = 1%).
- `royalty_address (address)`: Address to which royalty fees are sent when `Token` objects belonging to `Collection` are sold.
- `metadata_uri (String64)`: URI of collection's metadata file.
- `base_uri (String64)`: Prefix to `metadata_uri` of a `Token`'s metadata.
- `publicizable (bool)`: Wether `Token` objects belonging to `Collection` can be made public by their owner or not. It is an immutable data, even if `Collection`'s `updatable` attribute is true.

`CollectionPublicData` and `collection_id` uniqueness are enforced by:

```rust
mapping collectionPublicData: CollectionId => CollectionPublicData;
```

#### Token

##### Definition

A Token is a record containing data, defined as such :

```rust
record Token {
    owner: address,
    id: TokenId,
    data: TokenData
}
```

Every Token has a unique id:

```rust
struct TokenId {
    token_number: u128,
    collection_number: u128
}
```

__Attributes__:

- `token_number (u128)`: A unique 128 bits unsigned integer identifying the token.
- `collection_number (u128)`: The 128 bits unsigned integer identifying the collection the token belongs to.

And associated private data:

```rust
struct TokenData {
    metadata_uri: String64,
    transferable: bool
}
```

__Attributes__:

- `metadata_uri (String64)`: URI of token's metadata file.
- `transferable (bool)`: Wether token can be transferred or not.

##### Uniqueness

Token id uniqueness is enforced by:

```rust
mapping tokenExists: TokenId => bool;
```

##### Public token

A token can be made public by its owner, if its `Collection`'s `publicizable` attribute is true. It means its data and owner are public, enforced by:

```rust
mapping publicTokenData: TokenId => TokenData;
mapping publicTokenOwners: TokenId => address;
```

#### Proof

Proofs are records that guaranties conformity of an information without revealing the original data it is derived from. Three types of proofs can be provided.

##### Proof of ownership of a `Collection`

```rust
record CollectionOwnerProof {
    owner: address,
    prover: address,
    id: CollectionId,
    is_owner: bool,
    height: u32
}
```

__Attributes__:

- `owner (address)`: The addres the proof has been provided to.
- `prover (address)`: The address that provided the proof.
- `id (CollectionId)`: The id of the collection.
- `is_owner (bool)`: Wether the proof is a proof of ownership or holdership.
- `height (u32)`: The block height at which the proof is provided (with 50 blocks tolerance).

##### Proof of ownership of a `Token`

```rust
record TokenOwnerProof {
    owner: address,
    prover: address,
    id: TokenId,
    is_owner: bool,
    height: u32
}
```

__Attributes__:

- `owner (address)`: The addres the proof has been provided to.
- `prover (address)`: The address that provided the proof.
- `id (TokenId)`: The id of the token.
- `is_owner (bool)`: Wether the proof is a proof of ownership or holdership.
- `height (u32)`: The block height at which the proof is provided (with 50 blocks tolerance).

##### Proof of being a holder of at least one `Token` belonging to a `Collection`

```rust
record CollectionHolderProof {
    owner: address,
    prover: address,
    id: CollectionId,
    is_holder: bool,
    height: u32
}
```

__Attributes__:

- `owner (address)`: The addres the proof has been provided to.
- `prover (address)`: The address that provided the proof.
- `id (CollectionId)`: The id of the collection.
- `is_holder (bool)`: Wether the proof is a proof of holdership or ownership.
- `height (u32)`: The block height at which the proof is provided (with 50 blocks tolerance).

#### StringLENGTH

String are represented using a struct containing multiple unsigned integers.

```rust
struct String64 {
    part0: u128,
    part1: u128,
    part2: u128,
    part3: u128,
}
```

The amount of bytes, or ASCII characters, of data that can be stored is :
`LENGTH = USIZE * PARTS_AMOUNT / 8`
Hence with `USIZE = 128 and PARTS_AMOUNT = 4` we can store a 64 characters ASCII string.

### Transitions

#### Collection

##### Creation

To create a new `Collection` record, the following transition is used:

```rust
transition create_collection(
    private collection_number: u128, 
    private collection_data: CollectionData,
    public collection_public_data: CollectionPublicData,
) -> private Collection
```

__Arguments__:

- `collection_number (u128)`: The unique 128 bits unsigned integer identifying the collection.
- `collection_data (CollectionData)`: The collection private data.
- `collection_public_data (CollectionPublicData)`: The collection public data.

##### PublicData update

To update a `Collection`'s public data, the following transition is used:

```rust
transition update_collection_public_data(
    private collection: Collection,
    public collection_public_data: CollectionPublicData
) -> private Collection
```

__Arguments__:

- `collection (Collection)`: The collection to update.
- `collection_public_data (CollectionPublicData)`: The collection new public data.

##### Ownership transfer

To transfer the ownership of a `Collection`, the following transition is used:

```rust
transition transfer_collection(
    private collection: Collection,
    private receiver: address
) -> private Collection
```

__Arguments__:

- `collection (Collection)`: The collection to transfer.
- `receiver (address)`: The new owner of the collection.

##### Freeze collection updates

To freeze collection's `Token` objects `TokenData` updates, burns, and provide public proof of the freeze, the following transition is used:

```rust
transition freeze_collection_updates(
    private collection: Collection
) -> private Collection
```

__Arguments__:

- `collection (Collection)`: The collection to freeze.

#### Token

##### Private Mint

To mint a new `Token` as a `Collection` owner, the following transition is used:

```rust
transition mint_private(
    private collection: Collection, 
    public token_number: u128,
    private receiver: address,
    private token_data: TokenData
) -> (private Token, private Collection)
```

__Arguments__:

- `collection (Collection)`: The collection to mint the token from.
- `token_number (u128)`: The unique 128 bits unsigned integer identifying the token in the collection.
- `receiver (address)`: The first owner of the token.
- `token_data (TokenData)`: The token private data.

##### Private Burn

To remove permanently a private `Token` as a `Collection` owner, the following transition is used (collection owner must own said token):

```rust
transition burn_private(
    private collection: Collection,
    private token: Token
) -> private Collection
```

__Arguments__:

- `collection (Collection)`: The collection to burn the token from.
- `token (Token)`: The token to burn.

##### Public Burn

To remove permanently a public `Token` as a `Collection` owner, the following transition is used (collection owner doesn't need to own said token):

```rust
transition burn_public (
    private collection: Collection,
    public token_id: TokenId
) -> private Collection
```

__Arguments__:

- `collection (Collection)`: The collection to burn the token from.
- `token_id (TokenId)`: The id of the token to burn.

##### Transfer private

To transfer a private `Token` as its owner, the following transition is used:

```rust
transition transfer_token_private(
    private token: Token,
    private receiver: address
) -> private Token
```

__Arguments__:

- `token (Token)`: The token to transfer.
- `receiver (address)`: The new owner of the token.

##### Transfer public

To transfer a public `Token` as its owner, the following transition is used:

```rust
transition transfer_token_public(
    public token_id: TokenId,
    public receiver: address
)
```

__Arguments__:

- `token_id (TokenId)`: The id of the token to transfer.
- `receiver (address)`: The new owner of the token.

##### Transfer private to public

To transfer a private `Token` and make it public, as its owner, the following transition is used:

```rust
transition transfer_t_private_to_public(
    private token: Token, 
    public receiver: address
)
```

__Arguments__:

- `token (Token)`: The token to transfer.
- `receiver (address)`: The new owner of the token.

##### Transfer public to private

To transfer a public `Token` and make it private, as its owner, the following transition is used:

```rust
transition transfer_t_public_to_private(
    public token_id: TokenId,
    public token_data: TokenData,
    public receiver: address
) -> private Token
```

__Arguments__:

- `token_id (TokenId)`: The id of the token to transfer.
- `token_data (TokenData)`: The public data of the token to transfer.
- `receiver (address)`: The new owner of the token.

##### Update metadata private

To update the data of a private `Token` as a `Collection` owner, the following transition is used (collection owner must own said token):

```rust
transition update_token_data_private(
    private collection: Collection,
    private token: Token,
    private token_data: TokenData
) -> (private Token, private Collection)
```

__Arguments__:

- `collection (Collection)`: The collection the token belongs to.
- `token (Token)`: The token to update.
- `token_data (TokenData)`: The new data of the token to update.

##### Update metadata public

To update the data of a public `Token` as a `Collection` owner, the following transition is used (collection owner don't need to own said token):

```rust
transition update_token_data_public(
    private collection: Collection,
    public token_id: TokenId,
    public token_data: TokenData
) -> private Collection
```

__Arguments__:

- `collection (Collection)`: The collection the token belongs to.
- `token_id (TokenId)`: The id of the token to update.
- `token_data (TokenData)`: The new data of the token to update.

#### Proof

##### Prove Collection Ownership

To prove ownership of a collection without revealing its private data, the following transition is used:

```rust
transition prove_collection_ownership (
    private collection: Collection,
    private to: address,
    public height: u32,
) -> (private CollectionOwnerProof, private Collection)
```

__Arguments__:

- `collection (Collection)`: The collection to prove ownership of.
- `to (address)`: The address to prove ownership to.
- `height (u32)`: The block height at which the proof is provided.

##### Prove Token Ownership

To prove ownership of a token without revealing its private data, the following transition is used:

```rust
transition prove_token_ownership (
    private token: Token,
    private to: address,
    public height: u32
) -> (private TokenOwnerProof, private Token)
```

__Arguments__:

- `token (Token)`: The token to prove ownership of.
- `to (address)`: The address to prove ownership to.
- `height (u32)`: The block height at which the proof is provided.

##### Prove Collection Holdership

To prove being a holder of at least one token belonging to a collection without revealing which one nor its data, the following transition is used:

```rust
transition prove_collection_holdership (
    private token: Token,
    private to: address,
    public height: u32,
) -> (private CollectionHolderProof, private Token)
```

__Arguments__:

- `token (Token)`: The token to prove ownership of.
- `to (address)`: The address to prove ownership to.
- `height (u32)`: The block height at which the proof is provided.

## Public Minting

Public minting is a feature that allows anyone to mint a new `Token` for a `Collection` without being its owner. It is only available for a `Collection` which `publicizable` data attribute is `true`.

### Concepts

#### CollectionMint

##### Definition

A `CollectionMint` represents an autorisation to publicly mint `Token` objects without owning associated `Collection` record. A `Collection` can have an arbitrary amount of `CollectionMint` attached to it. A `CollectionMint` can have an arbitrary amount of `TokenMint` attached to it.

Every CollectionMint has a unique id:

```rust
struct CollectionMintId {
    collection_number: u128,
    mint_number: u128
}
```

##### Mint data and uniqueness

A CollectionMint has public MintData, a set of rules of the condition under which Token objects can be minted :

```rust
struct MintData {
    whitelist: bool,
    price: u64,
    treasury: address,
    start: u32,
    end: u32,
    random: bool
}
```

Mint data and `CollectionMint` id uniqueness are enforced using:

```rust
mapping collectionMintData: CollectionMintId => MintData;
```

##### Mint data description

__Whitelist__:
Wether anyone can publicly mint tokens or only members of the whitelist. The list is implemented using:

```rust
mapping mintWhitelists: AddressCollectionMintId => u64;
```

Using as an index:

```rust
struct AddressCollectionMintId {
    addr: address,
    collection_number: u128,
    mint_number: u128
}
```

__Price and treasury__
`price` is the amount of microcredits that will be sent to `treasury` address uppon public mint of a Token.

__Start and end__
Block height of start and end of the period when minting `Token` objects publicly is allowed.

__Random__
Wether accounts publicly minting `Token` objects can choose the Token id they are willing to mint or if the mint is random.

Random mint is implemented using those two mappings, defining a "list" of minted token numbers:

```rust
mapping randomMintTokenNumbers: IndexCollectionMintId => u128;
mapping randomMintLengths: CollectionMintId => u64;
```

Using as an index:

```rust
struct IndexCollectionMintId {
    index: u64,
    collection_number: u128,
    mint_number: u128
}
```

#### TokenMint

##### Definition

`Tokens` that can be publicly minted using a `CollectionMint` must be initialized first as `TokenMint` objects.

Every `TokenMint` has a unique id:

```rust
struct TokenMintId {
    collection_number: u128,
    token_number: u128,
    mint_number: u128
}
```

##### Token data and uniqueness

A `TokenMint` has public `TokenData`, the data that corresponding `Token` will have as an attribute once minted.

`TokenData` and `TokenMint` id uniqueness are enforced using:

```rust
mapping tokenMintData: TokenMintId => TokenData;
```

### Transitions

#### CollectionMint

##### Create or update a `CollectionMint`

To create or update a `CollectionMint` as a `Collection` owner, the following transition is used (collection `publicizable` attibute must be `true`):

```rust
transition set_collection_mint(
    private collection: Collection,
    public mint_number: u128,
    public mint_data: MintData,
) -> private Collection
```

__Arguments__:

- `collection (Collection)`: The collection to create or update a `CollectionMint` for.
- `mint_number (u128)`: The unique 128 bits unsigned integer identifying the `CollectionMint` in the collection.
- `mint_data (MintData)`: The `CollectionMint` public mint data.

##### Update Whitelist Spots for an Address

To update `CollectionMint` whitelist spots a specific address has as a `Collection` owner, the following transition is used:

```rust
transition update_whitelist(
    private collection: Collection,
    public mint_number: u128,
    public addr: address,
    public quantity: u64
) -> private Collection
```

__Arguments__:

- `collection (Collection)`: The collection to update `CollectionMint` whitelists.
- `mint_number (u128)`: The unique 128 bits unsigned integer identifying the `CollectionMint` in the collection.
- `addr (address)`: The address to update the whitelist spots for.
- `quantity (u64)`: The new amount of whitelist spots for the address.

#### TokenMint

##### Create a TokenMint

To create a `TokenMint` as a `Collection` owner, the following transition is used:

```rust
transition create_token_mint(
    private collection: Collection,
    public token_number: u128,
    public mint_number: u128,
    public token_data: TokenData
) -> private Collection
```

__Arguments__:

- `collection (Collection)`: The collection to create a `TokenMint` for.
- `token_number (u128)`: The unique 128 bits unsigned integer identifying the future `Token` in the collection.
- `mint_number (u128)`: The unique 128 bits unsigned integer identifying the `CollectionMint` in the collection.
- `token_data (TokenData)`: Token data future minted token will have.

##### Update a TokenMint

To update a `TokenMint` as a `Collection` owner, the following transition is used:

```rust
transition update_token_mint(
    private collection: Collection,
    public token_number: u128,
    public mint_number: u128,
    public index: u128,
    public token_data: TokenData
) -> private Collection
```

__Arguments__:

- `collection (Collection)`: The collection to update a `TokenMint` from.
- `token_number (u128)`: The unique 128 bits unsigned integer identifying the future `Token` to update in the collection.
- `mint_number (u128)`: The unique 128 bits unsigned integer identifying the `CollectionMint` in the collection.
- `index (u128)`: The index of the token to update in the `CollectionMint`'s `TokenMint` list.
- `token_data (TokenData)`: Token data future minted token will have.

##### Remove a TokenMint

To remove a `TokenMint` as a `Collection` owner, the following transition is used:

```rust
transition remove_token_mint(
    private collection: Collection,
    public token_number: u128,
    public mint_number: u128,
    public index: u128
) -> private Collection
```

__Arguments__:

- `collection (Collection)`: The collection to remove a `TokenMint` from.
- `token_number (u128)`: The unique 128 bits unsigned integer identifying the future `Token` to remove in the collection.
- `mint_number (u128)`: The unique 128 bits unsigned integer identifying the `CollectionMint` in the collection.
- `index (u128)`: The index of the token to remove in the `CollectionMint`'s `TokenMint` list.

##### Publicly Mint a Token

To publicly mint a `Token`, any user can use the following transition:

```rust
transition mint_public(
    public index_mint_id: IndexCollectionMintId,
    public token_number: u128
    public payment: credits.leo/credits,
    public treasury: address,
    public price: u64,
) -> (credits.leo/credits, credits.leo/credits)
```

__Arguments__:

- `index_mint_id (IndexCollectionMintId)`: The index of the `CollectionMint` and `TokenMint` to mint from.
- `token_number (u128)`: The unique 128 bits unsigned integer identifying the  `Token` to mint.
- `payment (credits.leo/credits)`: The amount of credits to pay to mint the token.
- `treasury (address)`: The address to send the payment to.
- `price (u64)`: The amount of microcredits to send to the treasury.

## Marketplace

### Concepts

#### Listing

A Listing is a struct corresponding to proposition from a seller of a specific token against a certain price (in microcredits). It is defined as:

```rust
struct Listing {
    seller: address,
    price: u64,
}
```

Listed Token objects are implemented using:

```rust
mapping listings: TokenId => Listing;
```

### Transitions

#### Listings

##### Create Listing

To sell a `Token` object to another user for a certain price, its owner can create a listing using the following transition:

```rust
transition create_listing(
    public token_id: TokenId,
    public price: u64
)
```

__Arguments__:

- `token_id (TokenId)`: The id of the token to sell.
- `price (u64)`: The price in microcredits the buyer will pay for.

##### Update Listing

To update an existing `Listing`, its owner can use the following transition:

```rust
transition update_listing (
    public token_id: TokenId,
    public price: u64
)
```

__Arguments__:

- `token_id (TokenId)`: The id of the token to update the listing of.
- `price (u64)`: The new price in microcredits the buyer will pay for.

##### Cancel Listing

To cancel an existing `Listing`, its owner can use the following transition:

```rust
transition cancel_listing(
    public token_id: TokenId
)
```

__Arguments__:

- `token_id (TokenId)`: The id of the token to cancel the listing of.

##### Accept Listing

To accept an existing `Listing`, the buyer can use the following transition:

```rust
transition accept_listing(
    public listing: Listing,
    private payment: credits.leo/credits,
    public royalty_fees: u64,
    public royalty_address: address,
    public token_id: TokenId,
    public token_data: TokenData
) -> (
    private Token, 
    credits.leo/credits, 
    credits.leo/credits, 
    credits.leo/credits, 
    credits.leo/credits
)
```

__Arguments__:

- `listing (Listing)`: The listing struct to accept.
- `payment (credits.leo/credits)`: The record to extract payment from.
- `royalty_fees (u64)`: The permyriad of the price to send to the creator of the token.
- `royalty_address (address)`: The address to send the royalty fees to.
- `token_id (TokenId)`: The id of the token to buy.
- `token_data (TokenData)`: The public data of the token to buy.

## Aliases

### Concepts

#### Alias

Alias are Token records, which `Collection` have reserved id:

```rust
CollectionId {
    collection_number: 0u128;
}
```

They can be minted by any account, first arrived first served. They are a standard for alias pointing to addresses. When an Alias is made public, the public owner address is said to be pointed to by the alias.

ASCII representation of `token_number` of the alias' `TokenId` corresponds to the string alias pointing to the address. Entering that string in a wallet or a dApp instead of an address should replace said string with corresponding address.

This collection cannot be created using `create_collection` transition and has its own transition to be initiated: `create_alias_collection`.

Associated `CollectionPublicData` is:

```rust
CollectionPublicData {
    royalty_fees: 0u64,
    royalty_address: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc,
    metadata_uri: String64 {
        part0: 0u128,
        part1: 0u128,
        part2: 0u128,
        part3: 0u128
    },
    base_uri: String64 {
        part0: 0u128,
        part1: 0u128,
        part2: 0u128,
        part3: 0u128
    },
    publicizable: true,
}
```

Its `CollectionData` is the following:

```rust
CollectionData {
    updatable: false
}
```

### Transitions

#### Alias

As Alias objects are simply Token objects they can leverage all Token transitions.

##### Create the Alias collection

Alias collection should be created at some point after contract deployment using the following transition.

```rust
transition create_alias_collection() -> private Collection
```

##### Mint an Alias

As Alias collection is owned by the null address, its tokens, Aliases cannot be minted either publicly or privately. Transition to mint Aliases, that can be called by anybody is:

```rust
transition mint_alias(
    public name: u128,
    private receiver: address,
    private metadata_uri: String64
) -> private Token
```

__Arguments__:

- `name (u128)`: The unique 128 bits unsigned integer identifying the alias.
- `receiver (address)`: The first owner of the alias.
- `metadata_uri (String64)`: The alias metadata_uri.

##### Update a private Alias

Owner of a private Alias can update its `metadata_uri` at anytime:

```rust
transition update_alias_metadata_private(
    private alias: Token,
    private metadata_uri: String64
) -> private Token
```

__Arguments__:

- `alias (Token)`: The alias to update.
- `metadata_uri (String64)`: The new alias metadata_uri.

##### Update a public Alias

Owner of a public Alias can update its `metadata_uri` at anytime:

```rust
transition update_alias_metadata_public(
    public token_id: TokenId,
    public metadata_uri: String64
)
```

__Arguments__:

- `token_id (TokenId)`: The id of the alias to update.
- `metadata_uri (String64)`: The new alias metadata_uri.
