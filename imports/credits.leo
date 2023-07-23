program credits.aleo{
    record credits{
        owner: address,
        microcredits: u64
    }
    transition join(a: credits, b:credits) -> credits{
        return credits{
            owner: a.owner,
            microcredits: a.microcredits + b.microcredits
        };
    }

    transition split(a: credits, amount: u64) -> (credits, credits) {
        let b: credits = credits{
            owner: a.owner,
            microcredits: amount
        };
        let c: credits = credits{
            owner: a.owner,
            microcredits: a.microcredits - amount
        };
        return (b, c);
    }

    transition transfer_private(a: credits, receiver: address, amount: u64) -> (credits, credits) {
        let b: credits = credits{
            owner: receiver,
            microcredits: amount
        };
        let c: credits = credits{
            owner: a.owner,
            microcredits: a.microcredits - amount
        };
        return (b, c);
    }

}
