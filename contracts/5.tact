import "@stdlib/deploy";

/*
  TASK 5 - NFT random swap 
  The smart contract contains a bunch of different NFTs.
  A user brings his NFT (sends it to the smart contract), with 2.1 TON (2 for admin's profit, 0.1 for gas) in attachment (as fee for swap).
  The smart contract randomly chooses some NFT from the available NFTs (including the newly incoming one) and gives it to the user in exchange for the brought NFT (but occasionally just returns user's NFT in some cases).
  Admin can deposit NFTs without swap logic. Any NFT received from the admin is considered deposited. Admin can't swap.
  Admin can withdraw all NFTs at once, and also all TONs collected from users as fees.
  Implement getter that will return NFT addresses held by the smart contract.
  Implement getter that will return the amount of admin`s profit collected.

  In details, the smart contract (later: SC) should have this logic:
  Messages
  * AdminWithdrawalProfit 
   - SC should check that sender is the admin / otherwise throw "Insufficient privelegies"
   - SC should send all collected fees to admin except 0.1 TON (use AdminFetchProfit message as body)
     In other words: after each such operation, the contract's balance should be equal to 0.1 TON (which are reserved for storage) and the rest should be sent to the admin
  * AdminWithdrawalAllNFTs
   - SC should check that incoming tx TON value is enough for NFT withdrawal. Specifically, at least: (1 + totalNftsHeld * 0.08) TONs. Otherwise throw "Insufficent funds"
   - SC should check that sender is the admin, throw "Invalid sender" otherwise
   - If all checks pass, SC should send NFTs one by one to the admin 
   - SC should be able to withdraw all NFTs by a single message from admin
  * OwnershipAssigned 
   - if prevOwner is the owner's (admin) address, then add NFT to the collection
   - if value of TON attached is less then 2.1 TON then stop execution and return NFT back,
     but only in case that TON attached is enough to process refund without losing TONs on the SC's balance
   - randomly select NFT to send from all the NFTs that smart contract has
   - send the selected NFT to the sender with all remaining balance (except for admin profit = fees collected from this and other swaps)
     In other words: the contract's balance should increase by exactly 2 TON, some incoming TONs will be consumed for gas and the remainings of the incoming TONs should be refunded to the sender
  
  Getters
  * profit
   - returns how much collected fees is available to withdraw for the admin (all fees minus 0.1 TON)
  * nfts
   - returns dict of held NFTs with NFT indexes (sequential numbers from 0, 1, 2 ... and up to 'totalNftsHeld-1') as keys and NFT address as values 
     the order of NFTs in this dictionary doesn't matter
*/

message AdminWithdrawalProfit {
  queryId: Int as uint64;
}

message AdminWithdrawalAllNFTs {
  queryId: Int as uint64;
}

message AdminFetchProfit {
  queryId: Int as uint64;
}

message(0x05138d91) OwnershipAssigned {
    queryId: Int as uint64;
    prevOwner: Address;
    forwardPayload: Slice as remaining; 
}

message(0x5fcc3d14) Transfer { 
    queryId: Int as uint64;            
    newOwner: Address; 
    responseDestination: Address; 
    customPayload: Cell?; 
    forwardAmount: Int as coins; 
    forwardPayload: Slice as remaining; 
}

message MyMessage {
  queryId: Int as uint64;
  sender: Address;
  startIndex: Int;
}

contract Task5 with Deployable {
  seed: Int as uint128;
  owner: Address;
  nfts: map<Int as uint16, Address>;
  totalNftsHold: Int;
  
  init(seed: Int, owner: Address) {
    self.owner = owner;
    self.seed = seed; // needed to deploy multiple smart contracts copies from one admin address
    self.totalNftsHold = 0;
  }

  receive(msg: OwnershipAssigned) {
      if msg.prevOwner == self.owner {
          self.nfts.set(self.totalNftsHold, sender());
          self.totalNftsHold = self.totalNftsHold + 1;
          return;
      }
      let ctx: Context = context();
      let forwardFee: Int = ctx.readForwardFee();
      if ctx.value < ton("2.1") {
          if ctx.value >= forwardFee {
              send(SendParameters{
                  to: sender(),
                  value: 0,
                  mode: SendRemainingValue + SendIgnoreErrors,
                  bounce: false,
                  body: Transfer {
                      queryId: msg.queryId,
                      newOwner: msg.prevOwner,
                      responseDestination: msg.prevOwner,
                      customPayload: null,
                      forwardAmount: 0,
                      forwardPayload: emptySlice()
                  }.toCell()
              });
          }
          return;
      } 

      let r: Int = random(0, self.totalNftsHold-1);
      let addr: Address? = null;
      if r == self.totalNftsHold-1 {
         addr = sender();
      } else {
        addr = self.nfts.get(r);
        self.nfts.set(r, sender());
      }
      nativeReserve(myBalance() - ctx.value + ton("2"), 0); // Increase amount by balance
      send(SendParameters{
          to: addr!!,
          value: 0,
          mode: SendRemainingBalance + SendIgnoreErrors,
          bounce: false,
          body: Transfer {
              queryId: msg.queryId,
              newOwner: msg.prevOwner,
              responseDestination: msg.prevOwner,
              customPayload: null,
              forwardAmount: 0,
              forwardPayload: emptySlice()
          }.toCell()
      });
  }

  receive(msg: AdminWithdrawalProfit) {
      require(sender() == self.owner, "Insufficient privelegies");
      nativeReserve(ton("0.1"), 0);
      send(SendParameters{
          to: self.owner,
          value: 0,
          mode: SendRemainingBalance + SendIgnoreErrors,
          bounce: false,
          body: AdminFetchProfit{
              queryId: msg.queryId
          }.toCell()
      });
  }

  receive(msg: MyMessage) {
    let tmpr: Int = msg.startIndex;
    let m: Int = min(self.totalNftsHold, 150+tmpr);
    let addr: Address? = null;
    while (tmpr < m) {
      send(SendParameters{
        to: self.nfts.get(tmpr)!!,
        value: ton("0.05"),
        mode: SendIgnoreErrors,
        bounce: false,
        body: beginCell()
          .storeUint(0x5fcc3d14, 32)
          .storeUint(msg.queryId, 64)
          .storeAddress(msg.sender)
          .storeAddress(msg.sender)
          .storeInt(0, 1)
          .storeCoins(0)
          .storeSlice(emptySlice())
          .endCell()
        });
      /*send(SendParameters{
        to: self.nfts.get(tmpr)!!,
        value: ton("0.05"),
        mode: SendIgnoreErrors,
        bounce: false,
        body: Transfer {
          queryId: msg.queryId,
          newOwner: msg.sender,
          responseDestination: msg.sender,
          customPayload: null,
          forwardAmount: 0,
          forwardPayload: emptySlice()
        }.toCell()
      });*/
      tmpr = tmpr + 1;
    }
    if m == self.totalNftsHold {
      self.nfts = emptyMap();
      self.totalNftsHold = 0;
      return;
    }
    msg.startIndex = m;
    send(SendParameters{
      to: myAddress(),
      value: 0,
      mode: SendRemainingBalance + SendIgnoreErrors,
      bounce: false,
      body: msg.toCell()
    });
  }

  receive(msg: AdminWithdrawalAllNFTs) {
      let ctx: Context = context();
      require(ctx.value >= ton("1") + self.totalNftsHold * ton("0.08"), "Insufficent funds");
      require(sender() == self.owner, "Invalid sender");
      send(SendParameters{
        to: myAddress(),
        value: 0,
        mode: SendRemainingBalance + SendIgnoreErrors,
        bounce: false,
        body: MyMessage{
          queryId: msg.queryId,
          sender: sender(),
          startIndex: 0
        }.toCell()
      });
  }

  get fun profit(): Int { 
      let result: Int = myBalance() - ton("0.1");
      if result > 0 {
        return result;
      }
      return 0;
  }
  
  get fun nfts(): map<Int as uint16, Address> {
      return self.nfts;
  }

  get fun totalNftsHold(): Int {
    return self.totalNftsHold;
  }

  get fun Balance(): Int {
    return myBalance();
  }

  get fun owner(): Address {
    return self.owner;
  }
}
