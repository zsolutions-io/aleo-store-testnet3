// Leo code for Aleo.store NFT standard and Marketplace
// Documentation is available at https://docs.aleo.store

import credits.leo;

program aleo_store_nft.aleo {
    record Token {
        owner: address,
        id: TokenId,
        data: TokenData
    }

    struct TokenId {
        token_number: u128,
        collection_number: u128
    }

    struct TokenData {
        metadata_uri: String64,
        transferable: bool
    }

    record Collection {
        owner: address,
        id: CollectionId,
        data: CollectionData
    }

    struct CollectionId {
        collection_number: u128
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

    struct String64 {
        part0: u128,
        part1: u128,
        part2: u128,
        part3: u128,
    }

    struct Listing {
        seller: address,
        price: u64,
    }

    record CollectionOwnerProof {
        owner: address,
        prover: address,
        id: CollectionId,
        is_owner: bool,
        height: u32
    }

    record CollectionHolderProof {
        owner: address,
        prover: address,
        id: CollectionId,
        is_holder: bool,
        height: u32
    }

    record TokenOwnerProof {
        owner: address,
        prover: address,
        id: TokenId,
        is_owner: bool,
        height: u32
    }

    // Collection mappings
    mapping collectionPublicData: CollectionId => CollectionPublicData;

    // Token mappings
    mapping tokenExists: TokenId => bool;
    mapping publicTokenData: TokenId => TokenData;
    mapping publicTokenOwners: TokenId => address;

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
        let collection_id: CollectionId = CollectionId {
            collection_number: collection_number
        };

        let collection: Collection = Collection {
            owner: self.caller,
            id: collection_id,
            data: collection_data
        };
        return collection then finalize(
            collection_id, 
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
            data: collection.data
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
    ) -> (private Token, private Collection) {
        let new_collection: Collection = Collection {
            owner: collection.owner,
            id: collection.id,
            data: collection.data
        };
        let token_id: TokenId = TokenId {
            collection_number: collection.id.collection_number,
            token_number: token_number
        };

        let token : Token = Token {
            owner: receiver,
            id: token_id,
            data: token_data
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
        private token: Token
    ) -> private Collection {
        assert_eq(token.id.collection_number, collection.id.collection_number);
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
            token.id
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
        let public_data_exists: bool = publicTokenData.contains(token_id);
        assert(public_data_exists);

        tokenExists.remove(token_id);
        publicTokenData.remove(token_id);
        listings.remove(token_id);
        publicTokenOwners.remove(token_id);
    }

    transition transfer_token_private(
        private token: Token,
        private receiver: address
    ) -> private Token {
        assert(token.data.transferable);
        let out_token: Token = Token {
            owner: receiver,
            id: token.id,
            data: token.data
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
            self.caller
        );
    }
    finalize transfer_token_public (
        public token_id: TokenId,
        public receiver: address,
        public caller: address
    ) {
        let token_owner: address = publicTokenOwners.get(token_id);
        let token_data: TokenData = publicTokenData.get(token_id);
        assert_eq(token_owner, caller);
        assert(token_data.transferable);
        publicTokenOwners.set(token_id, receiver);
    }

    transition transfer_t_program_to_public(
        public token_id: TokenId,
        public receiver: address
    ) {
        return then finalize(
            token_id,
            receiver,
            self.parent
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
    }


    transition transfer_t_private_to_public(
        private token: Token, 
        public receiver: address
    ) {
        assert(
            token.data.transferable.or(
                self.caller.eq(receiver)
            )
        );
        return then finalize(
            token.data,
            token.id,
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
    }

    transition transfer_t_public_to_private(
        public token_id: TokenId,
        public token_data: TokenData,
        public receiver: address
    ) -> private Token {
        assert(
            token_data.transferable.or(
                self.caller.eq(receiver)
            )
        );
        let out_token: Token = Token {
            owner: receiver,
            id: token_id,
            data: token_data
        };
        return out_token then finalize(
            token_id,
            token_data,
            self.caller
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
    }

    transition transfer_t_program_to_private(
        public token_id: TokenId,
        public token_data: TokenData,
        public receiver: address
    ) -> private Token {
        assert(
            token_data.transferable.or(
                self.caller.eq(receiver)
            )
        );
        let out_token: Token = Token {
            owner: receiver,
            id: token_id,
            data: token_data
        };
        return out_token then finalize(
            token_id,
            token_data,
            self.parent
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
    }

    transition update_token_data_private(
        private collection: Collection,
        private token: Token,
        private token_data: TokenData
    ) -> (private Token, private Collection) {
        assert_eq(token.id.collection_number, collection.id.collection_number);
        assert(collection.data.updatable);

        let out_collection: Collection = Collection {
            owner: collection.owner,
            id: collection.id,
            data: collection.data
        };
        let out_token: Token = Token {
            owner: token.owner,
            id: token.id,
            data: token_data
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
            self.caller
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
    }


    transition prove_collection_ownership (
        private collection: Collection,
        private to: address,
        public height: u32,
    ) -> (private CollectionOwnerProof, private Collection) {
        let collection_owner_proof: CollectionOwnerProof 
            = CollectionOwnerProof {
                owner: to,
                prover: self.caller,
                id: collection.id,
                is_owner: true,
                height: height
            };
        let out_collection: Collection = Collection {
            owner: collection.owner,
            id: collection.id,
            data: collection.data
        };
        return (collection_owner_proof, out_collection) then finalize(height);
    } 
    finalize prove_collection_ownership (
        public height: u32
    ) {
        assert(
            height.gte(block.height - block_height_threshold())
        );
    }

    transition prove_token_ownership (
        private token: Token,
        private to: address,
        public height: u32
    ) -> (private TokenOwnerProof, private Token) {
        let token_owner_proof: TokenOwnerProof = TokenOwnerProof {
            owner: to,
            prover: self.caller,
            id: token.id,
            is_owner: true,
            height: height
        };
        let out_token: Token = Token {
            owner: token.owner,
            id: token.id,
            data: token.data
        };
        return (token_owner_proof, out_token) then finalize(height);
    } 
    finalize prove_token_ownership (
        public height: u32
    ) {
        assert(
            height.gte(block.height - block_height_threshold())
        );
    }

    
    transition prove_collection_holdership (
        private token: Token,
        private to: address,
        public height: u32,
    ) -> (private CollectionHolderProof, private Token) {
        let collection_id: CollectionId = CollectionId {
            collection_number: token.id.collection_number
        };
        let token_holder_proof: CollectionHolderProof = CollectionHolderProof {
            owner: to,
            prover: self.caller,
            id: collection_id,
            is_holder: true,
            height: height
        };
        let out_token: Token = Token {
            owner: token.owner,
            id: token.id,
            data: token.data,
        };
        return (token_holder_proof, out_token) then finalize(height);
    } 
    finalize prove_collection_holdership (
        public height: u32
    ) {
        assert(
            height.gte(block.height - block_height_threshold())
        );
    }

    // Alias transitions

    transition mint_alias(
        public name: u128,
        private receiver: address,
        private metadata_uri: String64
    ) -> private Token {
        let token_id: TokenId = TokenId {
            collection_number: 0u128,
            token_number: name
        };

        let data: TokenData = TokenData {
            metadata_uri: metadata_uri,
            transferable: true
        };
        let alias : Token = Token {
            owner: receiver,
            id: token_id,
            data: data
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
        private alias: Token,
        private metadata_uri: String64
    ) -> private Token {
        let data: TokenData = TokenData {
            metadata_uri: metadata_uri,
            transferable: true
        };
        let out_alias : Token = Token {
            owner: alias.owner,
            id: alias.id,
            data: data
        };
        return out_alias;
    }

    transition update_alias_metadata_public(
        public token_id: TokenId,
        public metadata_uri: String64
    ) {
        return then finalize(token_id, metadata_uri, self.caller);
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

    // Marketplace transitions

    transition create_listing(
        public token_id: TokenId,
        public price: u64
    ) {
        return then finalize(self.caller, token_id, price);
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
    }

    transition update_listing (
        public token_id: TokenId,
        public price: u64
    ) {
        return then finalize(self.caller, token_id, price);
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
        return then finalize(self.caller, token_id);
    }
    finalize cancel_listing(
        public seller: address,
        public token_id: TokenId
    ) {
        let listing: Listing = listings.get(token_id);
        assert_eq(seller, listing.seller);
        publicTokenOwners.set(token_id, seller);
        listings.remove(token_id);
    }

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
    ) {
        let token: Token = Token {
            owner: self.caller,
            id: token_id,
            data: token_data
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
    inline block_height_threshold() -> u32 {
        return 50u32;
    }
}
