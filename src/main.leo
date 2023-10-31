// Leo code for Aleo.store NFT standard and Marketplace
// Documentation is available at https://docs.aleo.store

// Question Evan:
// TokenId -> TokenData ?
// Transferable boolean ?
// Royalties ?

// If collections have duplicates, then the editions should increment by one.

import credits.leo;

program aleo_store_nft.aleo {
    record NFT {
        owner: address,
        data: String64,
        edition: scalar,
        transferable: bool,
    }

    struct TokenId {
        token_number: u128,
        collection_number: u128,
    }

    struct CollectionId {
        collection_number: u128
    }

    struct String64 {
        part0: u128,
        part1: u128,
        part2: u128,
        part3: u128,
    }

    struct TokenData {
        metadata_uri: String64,
        transferable: bool,
    }

    record Collection {
        owner: address,
        data: CollectionData,
        id: CollectionId,
    }

    struct CollectionData {
        updatable: bool
    }

    struct CollectionPublicData {
        royalty_fees: u64,
        royalty_address: address,
        metadata_uri: String64,
        base_uri: String64,
        publicizable: bool
    }

    struct CollectionMintId {
        collection_number: u128,
        mint_number: u128
    }

    struct MintData {
        whitelist: bool,
        price: u64,
        treasury: address,
        start: u32,
        end: u32,
        random: bool
    }
    struct AddressCollectionMintId {
        addr: address,
        collection_number: u128,
        mint_number: u128
    }
    struct TokenMintId {
        collection_number: u128,
        token_number: u128,
        mint_number: u128
    }
    struct IndexCollectionMintId {
        index: u128,
        collection_number: u128,
        mint_number: u128
    }
    struct Listing {
        seller: address,
        price: u64,
    }
    // Collection mappings
    mapping collectionPublicData: CollectionId => CollectionPublicData;
    
    // Token mappings
    mapping tokenExists: TokenId => bool;
    mapping publicTokenData: TokenId => TokenData;
    mapping publicTokenOwners: TokenId => address;
    mapping nft_owners: field => address;

    // Public mint mappings
    mapping mintWhitelists: AddressCollectionMintId => u64;
    mapping collectionMintData: CollectionMintId => MintData;
    mapping tokenMintData: TokenMintId => TokenData;
    mapping mintTokenNumbers: IndexCollectionMintId => u128;
    mapping mintLengths: CollectionMintId => u128;

    // Marketplace mappings
    mapping listings: TokenId => Listing;
 
    transition create_collection(
        private collection_number: u128, 
        private collection_data: CollectionData,
        public collection_public_data: CollectionPublicData,
    ) -> private Collection {
        assert_neq(collection_number, 0u128);
        let collection: Collection = Collection {
            owner: self.signer,
            data: collection_data,
            id: CollectionId {
                collection_number: collection_number
            },
        };
        return collection then finalize(
            collection.id, 
            collection_public_data
        );
    }
    finalize create_collection(
        public collection_id: CollectionId,
        public collection_public_data: CollectionPublicData
    ) {
        let collection_exists: bool = collectionPublicData.contains(
            collection_id
        );
        assert(collection_exists.not());
        collectionPublicData.set(collection_id, collection_public_data);
    }
    transition update_collection_public_data(
        private collection: Collection,
        public collection_public_data: CollectionPublicData
    ) -> private Collection {
        let out_collection: Collection = Collection {
            owner: collection.owner,
            id: collection.id,
            data: collection.data,
        };
        return out_collection then finalize(
            collection.id, 
            collection_public_data
        );
    }
    finalize update_collection_public_data(
        public collection_id: CollectionId, 
        public collection_public_data: CollectionPublicData
    ){
        let former_collection_public_data: CollectionPublicData 
            = collectionPublicData.get(
                collection_id
            );
        assert_eq(
            former_collection_public_data.publicizable,
            collection_public_data.publicizable
        );
        collectionPublicData.set(collection_id, collection_public_data);
    }

    transition transfer_collection(
        private collection: Collection,
        private receiver: address
    ) -> private Collection {
        let out_collection: Collection = Collection {
            owner: receiver,
            id: collection.id,
            data: collection.data
        };
        return out_collection;
    }

    transition freeze_collection_updates(
        private collection: Collection
    ) -> private Collection {
        let out_collection_data: CollectionData = CollectionData {
            updatable: false
        };
        let out_collection: Collection = Collection {
            owner: collection.owner,
            id: collection.id,
            data: out_collection_data
        };
        return out_collection then finalize(
            collection.id
        );
    } // Public proof that collection cannot be updated anymore
    finalize freeze_collection_updates(
        public collection_id: CollectionId
    ) {
        assert(true);
    }

    transition mint_private(
        private collection: Collection, 
        public token_number: u128,
        private receiver: address,
        private token_data: TokenData
    ) -> (private NFT, private Collection) {
        let new_collection: Collection = Collection {
            owner: collection.owner,
            id: collection.id,
            data: collection.data
        };
        let token_id: TokenId = TokenId {
            collection_number: collection.id.collection_number,
            token_number: token_number
        };

        let token : NFT = NFT {
            owner: receiver,
            data: token_data.metadata_uri,
            edition: token_id_to_edition(token_id),
            transferable: token_data.transferable
        };
        return (token, new_collection) then finalize(token_id);
    }
    finalize mint_private(
        public token_id: TokenId,
    ) {
        let token_exists: bool = tokenExists.contains(token_id);
        assert(token_exists.not());

        tokenExists.set(token_id, true);
    }

    transition burn_private(
        private collection: Collection,
        private token: NFT
    ) -> private Collection {
        let token_id: TokenId = token_edition_to_id(token.edition);
        assert_eq(token_id.collection_number, collection.id.collection_number);
        assert(collection.data.updatable);

        let collection_data: CollectionData = CollectionData {
            updatable: collection.data.updatable,
        };

        let new_collection: Collection = Collection {
            owner: collection.owner,
            id: collection.id,
            data: collection_data
        };

        return new_collection then finalize(
            token_id
        );
    }
    finalize burn_private(
        public token_id: TokenId
    ) {
        tokenExists.remove(token_id);
    }

    transition burn_public (
        private collection: Collection,
        public token_id: TokenId
    ) -> private Collection {
        assert_eq(token_id.collection_number, collection.id.collection_number);
        assert(collection.data.updatable);

        let new_collection: Collection = Collection {
            owner: collection.owner,
            id: collection.id,
            data: collection.data
        };

        return new_collection then finalize(
            collection.id,
            token_id
        );
    }
    finalize burn_public (
        public collection_id: CollectionId,
        public token_id: TokenId
    ) {
        let is_listed: bool = listings.contains(token_id);
        let public_token_data: TokenData = publicTokenData.get(token_id);

        tokenExists.remove(token_id);
        publicTokenData.remove(token_id);
        listings.remove(token_id);
        publicTokenOwners.remove(token_id);
        nft_owners.remove(
            token_id_to_hash(token_id, public_token_data.metadata_uri)
        );
    }

    transition transfer_token_private(
        private token: NFT,
        private receiver: address
    ) -> private NFT {
        assert(token.transferable);
        let out_token: NFT = NFT {
            owner: receiver,
            data: token.data,
            edition: token.edition,
            transferable: token.transferable
        };
        return out_token;
    }

    transition transfer_token_public(
        public token_id: TokenId,
        public receiver: address
    ) {
        return then finalize(
            token_id,
            receiver,
            self.signer
        );
    }
    finalize transfer_token_public(
        public token_id: TokenId,
        public receiver: address,
        public caller: address
    ) {
        let token_owner: address = publicTokenOwners.get(token_id);
        let token_data: TokenData = publicTokenData.get(token_id);
        assert_eq(token_owner, caller);
        assert(token_data.transferable);
        publicTokenOwners.set(token_id, receiver);

        nft_owners.set(
            token_id_to_hash(token_id, token_data.metadata_uri),
            receiver
        );
    }

    transition transfer_t_program_to_public(
        public token_id: TokenId,
        public receiver: address
    ) {
        return then finalize(
            token_id,
            receiver,
            self.caller
        );
    }
    finalize transfer_t_program_to_public(
        public token_id: TokenId,
        public receiver: address,
        public parent: address
    ) {
        let token_owner: address = publicTokenOwners.get(token_id);
        let token_data: TokenData = publicTokenData.get(token_id);
        assert_eq(token_owner, parent);
        assert(token_data.transferable);
        publicTokenOwners.set(token_id, receiver);
        nft_owners.set(
            token_id_to_hash(token_id, token_data.metadata_uri),
            receiver
        );
    }

    transition transfer_t_private_to_public(
        private token: NFT, 
        public receiver: address
    ) {
        assert(token.transferable || self.signer == receiver);
        let token_data: TokenData = TokenData {
            metadata_uri: token.data,
            transferable: token.transferable
        };
        return then finalize(
            token_data,
            token_edition_to_id(token.edition),
            receiver
        );
    }
    finalize transfer_t_private_to_public(
        public token_data: TokenData, 
        public token_id: TokenId,
        public receiver: address,
    ) {
        let collection_id: CollectionId = CollectionId {
            collection_number: token_id.collection_number
        };
        let collection_public_data: CollectionPublicData
            = collectionPublicData.get(collection_id);
        assert(collection_public_data.publicizable);
        publicTokenData.set(token_id, token_data);
        publicTokenOwners.set(token_id, receiver);
        nft_owners.set(
            token_id_to_hash(token_id, token_data.metadata_uri),
            receiver
        );
    }

    transition transfer_t_public_to_private(
        public token_id: TokenId,
        public token_data: TokenData,
        public receiver: address
    ) -> private NFT {
        assert(token_data.transferable || self.signer == receiver);
        let out_token: NFT = NFT {
            owner: receiver,
            data: token_data.metadata_uri,
            edition: token_id_to_edition(token_id),
            transferable: token_data.transferable
        };
        return out_token then finalize(
            token_id,
            token_data,
            self.signer
        );
    }
    finalize transfer_t_public_to_private(
        public token_id: TokenId,
        public token_data: TokenData,
        public caller: address
    ) {
        let stored_token_data: TokenData = publicTokenData.get(token_id);
        let owner: address = publicTokenOwners.get(token_id);

        assert_eq(owner, caller);
        assert_eq(token_data, stored_token_data);

        publicTokenOwners.remove(token_id);
        publicTokenData.remove(token_id);
        nft_owners.remove(
            token_id_to_hash(token_id, token_data.metadata_uri)
        );
    }

    transition transfer_t_program_to_private(
        public token_id: TokenId,
        public token_data: TokenData,
        public receiver: address
    ) -> private NFT {
        assert(token_data.transferable);
        let out_token: NFT = NFT {
            owner: receiver,
            data: token_data.metadata_uri,
            edition: token_id_to_edition(token_id),
            transferable: token_data.transferable
        };
        return out_token then finalize(
            token_id,
            token_data,
            self.caller
        );
    }
    finalize transfer_t_program_to_private(
        public token_id: TokenId,
        public token_data: TokenData,
        public parent: address
    ) {
        let stored_token_data: TokenData = publicTokenData.get(token_id);
        let owner: address = publicTokenOwners.get(token_id);

        assert_eq(owner, parent);
        assert_eq(token_data, stored_token_data);

        publicTokenOwners.remove(token_id);
        publicTokenData.remove(token_id);
        nft_owners.remove(
            token_id_to_hash(token_id, token_data.metadata_uri)
        );
    }


    transition update_token_data_private(
        private collection: Collection,
        private token: NFT,
        private token_data: TokenData
    ) -> (private NFT, private Collection) {
        let token_id: TokenId = token_edition_to_id(token.edition);
        assert_eq(token_id.collection_number, collection.id.collection_number);
        assert(collection.data.updatable);

        let out_collection: Collection = Collection {
            owner: collection.owner,
            id: collection.id,
            data: collection.data
        };
        let out_token: NFT = NFT {
            owner: token.owner,
            data: token_data.metadata_uri,
            edition: token.edition,
            transferable: token_data.transferable
        };
        return (out_token, out_collection);
    }

    transition update_token_data_public(
        private collection: Collection,
        public token_id: TokenId,
        public token_data: TokenData
    ) -> private Collection {
        assert_eq(token_id.collection_number, collection.id.collection_number);
        assert(collection.data.updatable);

        let out_collection: Collection = Collection {
            owner: collection.owner,
            id: collection.id,
            data: collection.data
        };
        return out_collection then finalize(
            token_id,
            token_data
        );
    }
    finalize update_token_data_public(
        public token_id: TokenId,
        public token_data: TokenData
    ) {
        publicTokenData.set(token_id, token_data);
    }

    
    transition set_collection_mint(
        private collection: Collection,
        public mint_number: u128,
        public mint_data: MintData,
    ) -> private Collection {
        let out_collection: Collection = Collection {
            owner: collection.owner,
            id: collection.id,
            data: collection.data
        };

        let collection_mint_id: CollectionMintId = CollectionMintId {
            collection_number: collection.id.collection_number,
            mint_number: mint_number
        };

        return out_collection then finalize (
            collection_mint_id,
            mint_data
        );
    }
    finalize set_collection_mint(
        public collection_mint_id: CollectionMintId,
        public mint_data: MintData
    ) {
        // Check collection publicizable
        let collection_id: CollectionId = CollectionId {
            collection_number: collection_mint_id.collection_number
        };
        let public_collection_data: CollectionPublicData 
            = collectionPublicData.get(collection_id);
        assert(public_collection_data.publicizable);

        collectionMintData.set(collection_mint_id, mint_data);
    }


    transition create_token_mint(
        private collection: Collection,
        public token_number: u128,
        public mint_number: u128,
        public token_data: TokenData
    ) -> private Collection {
        let out_collection: Collection = Collection{
            owner: collection.owner,
            id: collection.id,
            data: collection.data
        };

        let collection_mint_id: CollectionMintId = CollectionMintId {
            collection_number: collection.id.collection_number,
            mint_number: mint_number
        };

        return out_collection then finalize(
            collection_mint_id,
            token_number,
            token_data,
        );
    }
    finalize create_token_mint(
        public collection_mint_id: CollectionMintId,
        public token_number: u128,
        public token_data: TokenData,
    ) {
        let mint_length: u128 = mintLengths.get_or_use(
            collection_mint_id, 0u128
        );
        let index_mint_id: IndexCollectionMintId = IndexCollectionMintId {
            collection_number: collection_mint_id.collection_number,
            mint_number: collection_mint_id.mint_number,
            index: mint_length
        };
        let token_mint_id: TokenMintId = TokenMintId {
            collection_number: collection_mint_id.collection_number,
            mint_number: collection_mint_id.mint_number,
            token_number: token_number
        };
        mintLengths.set(
            collection_mint_id, mint_length + 1u128
        );
        mintTokenNumbers.set(
            index_mint_id, token_number
        );
        tokenMintData.set(token_mint_id, token_data);
    }


    transition update_token_mint(
        private collection: Collection,
        public token_number: u128,
        public mint_number: u128,
        public index: u128,
        public token_data: TokenData
    ) -> private Collection {
        let out_collection: Collection = Collection{
            owner: collection.owner,
            id: collection.id,
            data: collection.data
        };

        let token_mint_id: TokenMintId = TokenMintId {
            collection_number: collection.id.collection_number,
            token_number: token_number,
            mint_number: mint_number,
        };

        return out_collection then finalize(
            token_mint_id,
            index,
            token_data,
        );
    }
    finalize update_token_mint(
        public token_mint_id: TokenMintId,
        public index: u128,
        public token_data: TokenData,
    ) {
        let index_mint_id: IndexCollectionMintId = IndexCollectionMintId {
            collection_number: token_mint_id.collection_number,
            mint_number: token_mint_id.mint_number,
            index: index
        };
        let stored_token_number: u128 = mintTokenNumbers.get(
            index_mint_id
        );
        assert_eq(stored_token_number, token_mint_id.token_number);

        tokenMintData.set(token_mint_id, token_data);
    }


    transition remove_token_mint(
        private collection: Collection,
        public token_number: u128,
        public mint_number: u128,
        public index: u128,
    ) -> private Collection {
        let index_mint_id: IndexCollectionMintId = IndexCollectionMintId {
            collection_number: collection.id.collection_number,
            mint_number: mint_number,
            index: index
        };
        let out_collection: Collection = Collection{
            owner: collection.owner,
            id: collection.id,
            data: collection.data
        };

        return out_collection then finalize(
            index_mint_id,
            token_number
        );
    }
    finalize remove_token_mint(
        public index_mint_id: IndexCollectionMintId,
        public token_number: u128
    ) {
        // Check token numbers match
        let stored_token_number: u128 = mintTokenNumbers.get(index_mint_id);
        assert_eq(stored_token_number, token_number);

        // Update mint list
        let collection_mint_id: CollectionMintId = CollectionMintId {
            collection_number: index_mint_id.collection_number,
            mint_number: index_mint_id.mint_number
        };
        let mint_length: u128 = mintLengths.get(collection_mint_id);
        let new_mint_length: u128 = mint_length - 1u128;
        mintLengths.set(collection_mint_id, new_mint_length);
        let last_index_mint_id: IndexCollectionMintId 
            = IndexCollectionMintId {
                collection_number: index_mint_id.collection_number,
                mint_number: index_mint_id.mint_number,
                index: new_mint_length
            };
        let last_token_number: u128 = mintTokenNumbers.get(last_index_mint_id);
        mintTokenNumbers.set(index_mint_id, last_token_number);
        mintTokenNumbers.remove(last_index_mint_id);

        let token_mint_id: TokenMintId = TokenMintId {
            collection_number: index_mint_id.collection_number,
            token_number: token_number,
            mint_number: index_mint_id.mint_number
        };
        tokenMintData.remove(token_mint_id);
    }

    transition update_whitelist(
        private collection: Collection,
        public mint_number: u128,
        public addr: address,
        public quantity: u64
    ) -> private Collection {
        let out_collection: Collection = Collection {
            owner: collection.owner,
            id: collection.id,
            data: collection.data
        };
        let address_collection_mint_id: AddressCollectionMintId 
            = AddressCollectionMintId {
                addr: addr,
                collection_number: collection.id.collection_number,
                mint_number: mint_number
            };

        return out_collection then finalize(
            address_collection_mint_id,
            quantity
        );
    }
    finalize update_whitelist(
        public address_collection_mint_id: AddressCollectionMintId,
        public quantity: u64
    ) {
        mintWhitelists.set(
            address_collection_mint_id, 
            quantity
        );
    }


    transition mint_public(
        public index_mint_id: IndexCollectionMintId,
        public token_number: u128,
        public payment: credits.leo/credits,
        public treasury: address,
        public price: u64,
    ) -> (credits.leo/credits, credits.leo/credits) {
        let (out_seller, out_buyer): (credits, credits) 
            = credits.leo/transfer_private(
                payment,
                treasury,
                price
            );
        return (out_buyer, out_seller) then finalize(
            index_mint_id,
            token_number,
            treasury,
            price,
            self.signer
        );
    } finalize mint_public (
        public input_index_mint_id: IndexCollectionMintId,
        public input_token_number: u128,
        public treasury: address,
        public price: u64,
        public caller: address,
    ) {
        let collection_mint_id: CollectionMintId = CollectionMintId {
            collection_number: input_index_mint_id.collection_number,
            mint_number: input_index_mint_id.mint_number
        };
        let mint_data: MintData = collectionMintData.get(collection_mint_id);
        
        // Generate random or input token number
        let mint_length: u128 = mintLengths.get(collection_mint_id);
        let index: u128 = mint_data.random ? (
            ChaCha::rand_u128() % mint_length
        ) : (
            input_index_mint_id.index
        );
        
        // Check token number matches
        let index_mint_id: IndexCollectionMintId = IndexCollectionMintId {
            collection_number: collection_mint_id.collection_number,
            mint_number: collection_mint_id.mint_number,
            index: index
        };
        let token_number: u128 = mintTokenNumbers.get(index_mint_id);
        assert(
            mint_data.random.or(
                token_number.eq(
                    input_token_number
                )
            )
        );

        // Check token exists
        let token_id: TokenId = TokenId {
            collection_number: collection_mint_id.collection_number,
            token_number: token_number
        };
        let token_exists: bool = tokenExists.contains(token_id);
        assert(token_exists.not());

        // Check whitelist
        let address_collection_mint_id: AddressCollectionMintId 
            = AddressCollectionMintId {
                addr: caller,
                collection_number: collection_mint_id.collection_number,
                mint_number: collection_mint_id.mint_number
            };
        let stored_address_collection_whitelist: u64
            = mintWhitelists.get_or_use(
                address_collection_mint_id, 0u64
            );

        let address_collection_whitelist: u64 = mint_data.whitelist ? 
            stored_address_collection_whitelist : 1u64;
        let new_address_collection_whitelist: u64 = (
            address_collection_whitelist - 1u64
        );
        mintWhitelists.set(
            address_collection_mint_id, new_address_collection_whitelist
        );

        // Check mint block heights
        assert(
            mint_data.start.eq(0u32).or(
                mint_data.start <= block.height
            )
        );
        assert(
            mint_data.end.eq(0u32).or(
                block.height < mint_data.end
            )
        );

        // Check mint payment
        assert_eq(price, mint_data.price);
        assert_eq(treasury, mint_data.treasury);

        // Update mint list
        let new_mint_length: u128 = mint_length - 1u128;
        mintLengths.set(collection_mint_id, new_mint_length);
        let last_index_mint_id: IndexCollectionMintId 
            = IndexCollectionMintId {
                collection_number: collection_mint_id.collection_number,
                mint_number: collection_mint_id.mint_number,
                index: new_mint_length
            };
        let last_token_number: u128 = mintTokenNumbers.get(last_index_mint_id);
        mintTokenNumbers.set(last_index_mint_id, last_token_number);
        mintTokenNumbers.remove(index_mint_id);

        // Set public token
        tokenExists.set(token_id, true);
        publicTokenOwners.set(token_id, caller);
        // Set token data
        let token_mint_id: TokenMintId = TokenMintId {
            collection_number: collection_mint_id.collection_number,
            token_number: token_number,
            mint_number: input_index_mint_id.mint_number
        };
        let token_data: TokenData = tokenMintData.get(token_mint_id);
        publicTokenData.set(token_id, token_data);
        nft_owners.set(
            token_id_to_hash(token_id, token_data.metadata_uri),
            caller
        );

    }

    transition mint_alias(
        public name: u128,
        private receiver: address,
        private metadata_uri: String64
    ) -> private NFT {
        let token_id: TokenId = TokenId {
            collection_number: 0u128,
            token_number: name
        };
        let alias : NFT = NFT {
            owner: receiver,
            data: metadata_uri,
            edition: token_id_to_edition(token_id),
            transferable: true
        };
        return alias then finalize(token_id);
    }
    finalize mint_alias(
        public token_id: TokenId,
    ) {
        let token_exists: bool = tokenExists.contains(token_id);
        assert(token_exists.not());

        tokenExists.set(token_id, true);
    }
    
    transition update_alias_metadata_private(
        private alias: NFT,
        private metadata_uri: String64
    ) -> private NFT {
        let out_alias : NFT = NFT {
            owner: alias.owner,
            data: metadata_uri,
            edition: alias.edition,
            transferable: alias.transferable
        };
        return out_alias;
    }

    transition update_alias_metadata_public(
        public token_id: TokenId,
        public metadata_uri: String64
    ) {
        return then finalize(token_id, metadata_uri, self.signer);
    }
    finalize update_alias_metadata_public(
        token_id: TokenId,
        metadata_uri: String64,
        caller: address,
    ) {
        let owner: address = publicTokenOwners.get(token_id);
        assert_eq(owner, caller);

        publicTokenData.set(
            token_id,
            TokenData {
                metadata_uri: metadata_uri,
                transferable: true
            }
        );
    }

    transition create_alias_collection() -> private Collection {
        let collection_data: CollectionData = CollectionData {
            updatable: false
        };

        let collection: Collection = Collection {
            owner: new_address(),
            id: new_collection_id(),
            data: collection_data
        };
        return collection then finalize();
    }
    finalize create_alias_collection() {
        let collection_exists: bool = collectionPublicData.contains(
            new_collection_id()
        );
        assert(collection_exists.not());

        collectionPublicData.set(
            new_collection_id(), 
            new_collection_public_data()
        );
    }

    transition create_listing(
        public token_id: TokenId,
        public price: u64
    ) {
        return then finalize(self.signer, token_id, price);
    }
    finalize create_listing (
        public seller: address,
        public token_id: TokenId,
        public price: u64
    ) {
        let token_owner: address = publicTokenOwners.get(token_id);
        assert_eq(token_owner, seller);

        let token_data: TokenData = publicTokenData.get(token_id);
        assert(token_data.transferable);

        let listing: Listing = Listing {
            seller: seller,
            price: price
        };
        listings.set(token_id, listing);
        publicTokenOwners.remove(token_id);
        nft_owners.remove(
            token_id_to_hash(token_id, token_data.metadata_uri)
        );
    }

    transition update_listing (
        public token_id: TokenId,
        public price: u64
    ) {
        return then finalize(self.signer, token_id, price);
    }
    finalize update_listing (
        public seller: address,
        public token_id: TokenId,
        public price: u64
    ) {
        let listing: Listing = listings.get(token_id);
        assert_eq(seller, listing.seller);
        let new_listing: Listing = Listing {
            seller: seller,
            price: price
        };
        listings.set(token_id, new_listing);
    }

    transition cancel_listing(
        public token_id: TokenId
    ) {
        return then finalize(self.signer, token_id);
    }
    finalize cancel_listing(
        public seller: address,
        public token_id: TokenId
    ) {
        let listing: Listing = listings.get(token_id);
        assert_eq(seller, listing.seller);
        publicTokenOwners.set(token_id, seller);
        let token_data: TokenData = publicTokenData.get(token_id);
        listings.remove(token_id);
        nft_owners.remove(
            token_id_to_hash(token_id, token_data.metadata_uri)
        );
    }

    transition accept_listing(
        public listing: Listing,
        private payment: credits.leo/credits,
        public royalty_fees: u64,
        public royalty_address: address,
        public token_id: TokenId,
        public token_data: TokenData
    ) -> (
        private NFT, 
        credits.leo/credits, 
        credits.leo/credits, 
        credits.leo/credits, 
        credits.leo/credits
    ) {
        let token: NFT = NFT {
            owner: self.signer,
            data: token_data.metadata_uri,
            edition: token_id_to_edition(token_id),
            transferable: token_data.transferable
        };
        let price: u64 = listing.price;
        let royality_amount: u64 = (royalty_fees * price).div(10000u64);
        let market_amount: u64 = (market_fees() * price).div(10000u64);
        let seller_amount: u64 = price - royality_amount - market_amount;
        
        let (out_market, payment1): (credits, credits) 
            = credits.leo/transfer_private(
                payment,
                market_fees_address(),
                market_amount
            );
        let (out_royalties, payment2) : (credits, credits) 
            = credits.leo/transfer_private(
                payment1,
                royalty_address,
                royality_amount
            );
        let (out_seller, out_buyer): (credits, credits) 
            = credits.leo/transfer_private(
                payment2,
                listing.seller,
                seller_amount
            );
        return (
            token, 
            out_market, 
            out_royalties,
            out_buyer,
            out_seller
        ) then finalize(
            listing,
            token_id,
            token_data,
            royalty_fees,
            royalty_address
        );
    }
    finalize accept_listing(
        public listing: Listing,
        public token_id: TokenId,
        public token_data: TokenData,
        public royalty_fees: u64,
        public royalty_address: address,
    ) {
        let retrieved_listing: Listing = listings.get(token_id);
        assert_eq(listing, retrieved_listing);

        let retrieved_token_data: TokenData = publicTokenData.get(token_id);
        assert_eq(token_data, retrieved_token_data);

        let collection_id: CollectionId = CollectionId {
            collection_number: token_id.collection_number
        };
        let collection_public_data: CollectionPublicData 
            = collectionPublicData.get(collection_id);
        assert_eq(
            collection_public_data.royalty_fees, royalty_fees
        );
        assert_eq(
            collection_public_data.royalty_address, royalty_address
        );
        listings.remove(token_id);
        publicTokenData.remove(token_id);
    }

    // Arc0721
    transition convert_private_to_public(
        private token: NFT
    ) {
        let token_data: TokenData = TokenData {
            metadata_uri: token.data,
            transferable: token.transferable
        };
        return then finalize(
            self.signer,
            token_edition_to_hash(token.edition, token.data),
            token_data,
            token_edition_to_id(token.edition),
        );
    }
    finalize convert_private_to_public(
        public owner: address,
        public hash: field,
        public token_data: TokenData, 
        public token_id: TokenId,
    ) {
        let collection_id: CollectionId = CollectionId {
            collection_number: token_id.collection_number
        };
        let collection_public_data: CollectionPublicData
            = collectionPublicData.get(collection_id);
        assert(collection_public_data.publicizable);
        publicTokenData.set(token_id, token_data);
        publicTokenOwners.set(token_id, owner);
        nft_owners.set(hash, owner);
    }

    transition transfer_public(
        private receiver: address,
        private data: String64,
        private edition: scalar,
    ) {
        return then finalize(
            token_edition_to_hash(edition, data),
            receiver,
            self.signer,
            token_edition_to_id(edition),
            data
        );
    }
    finalize transfer_public(
        public hash: field,
        public receiver: address,
        public caller: address,
        public token_id: TokenId,
        public data: String64
    ) {
        let token_owner: address = publicTokenOwners.get(token_id);
        let token_data: TokenData = publicTokenData.get(token_id);
        assert_eq(token_owner, caller);
        assert_eq(data, token_data.metadata_uri);
        assert(token_data.transferable);
        publicTokenOwners.set(token_id, receiver);
        nft_owners.set(hash, receiver);
    }

    inline new_string64() -> String64 {
        return String64 {
            part0: 0u128,
            part1: 0u128,
            part2: 0u128,
            part3: 0u128
        };
    }
    inline new_address() -> address {
        return aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;
    }
    inline new_collection_id() -> CollectionId {
        return CollectionId {
            collection_number: 0u128
        };
    }
    inline new_collection_public_data() -> CollectionPublicData {
        return CollectionPublicData {
            royalty_fees: 0u64,
            royalty_address: new_address(),
            metadata_uri: new_string64(),
            base_uri: new_string64(),
            publicizable: true,
        };
    }
    inline market_fees_address() -> address {
        return aleo1xg4897p9ea8cd4cqpm2fzq9nthjr8caa377u3a3jqv9ff9u4f5gq3kut0m;
    }
    inline market_fees() -> u64 {
        return 250u64;
    }

    inline token_id_to_edition(  
        token_id: TokenId
    ) -> scalar {
        let collection_number_field: field = token_id.collection_number as field;
        let token_number_field: field = token_id.token_number as field;
        let bit_shift: field = 2field ** 126field; 
        assert(collection_number_field < bit_shift);
        assert(token_number_field < bit_shift);
        return (
            token_number_field + collection_number_field * bit_shift
        ) as scalar;
    }
    inline token_edition_to_id(
        token_edition: scalar,
    ) -> TokenId {
        let bit_shift: field = 2field ** 126field;
        let token_edition_field: field = token_edition as field;
        let token_edition_u128: u128 = token_edition as u128;
        let token_number: u128 = token_edition_u128 & 2u128**126u8 - 1u128;
        let remaining: field = token_edition_field - token_number as field;
        let collection_number: u128 = (remaining/bit_shift) as u128;

        return TokenId{
            collection_number: collection_number,
            token_number: token_number
        };
    }
    inline token_id_to_hash(
        id: TokenId,
        data: String64,
    ) -> field {
        return token_edition_to_hash(token_id_to_edition(id), data);
    }
    inline token_edition_to_hash(
        edition: scalar,
        data: String64,
    ) -> field {
        let token_hash: field = BHP256::hash_to_field(data);
        return BHP256::commit_to_field(token_hash, edition);
    }
}
