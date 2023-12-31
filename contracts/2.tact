import "@stdlib/deploy";

/*
  TASK 2 - Proxy 
  Create a contract that forwards all received TONs
  to the admin contract (whose address is set in init_store).
  Message from this proxy contract to the admin contract should contain:
    - Address of user who sent original message (should be stored in the outcoming body's data/bits)
    - Original message that proxy smart contract received from user (should be stored in the outcoming body's first ref)
  Also, if admin contract decides to reject message (if it sends to the proxy "Refund" message with opcode=0x44),
  proxy contract needs to forward all TONs (attached to Refund message) back to the user.
  User address will be provided in Refund message body as "sender".
  In refund transaction, it is important to have a check that the refund message came from the admin address
*/

message(0x44) Refund {
  queryId: Int as uint64;
  sender: Address;
}

/*contract Admin with Deployable {
    queryId: Int as uint64;
    init() {
        self.queryId = 0;
    }
    receive(msg: Forward) {
        let ctx: Context = context();
        send(SendParameters{
            to: ctx.sender,
            value: ctx.value,
            mode: SendIgnoreErrors,
            bounce: false,
            body: Refund{
                queryId: self.queryId,
                sender: msg.address 
            }.toCell()
        });
        self.queryId = self.queryId + 1;
    }
}*/

// Proxy
contract Task2 with Deployable {
  admin: Address;

  init(admin: Address) {
      self.admin = admin;
  }
  receive(msg: Refund) {
      // sender needs to be from admin address
      require(sender() == self.admin, "Refund sender should be admin");
      // return the fund back to the user
      nativeSendMessage(beginCell()
        .storeUint(0x18, 6)
        .storeAddress(msg.sender)
        .storeCoins(0)
        .storeUint(1, 1+4+4+64+32+1+1)
        .storeRef(emptyCell())
        .endCell(), 64);

      /*send(SendParameters{
          to: msg.sender,
          value: 0,
          mode: SendRemainingValue + SendIgnoreErrors
      });*/
  }

  receive(msg: Slice) {
      nativeSendMessage(beginCell()
        .storeUint(0x18, 6)
        .storeAddress(self.admin)
        .storeCoins(0)
        .storeUint(1, 1+4+4+64+32+1+1)
        .storeRef(beginCell().storeAddress(sender()).storeRef(msg.asCell()).endCell())
        .endCell(), 64);
      /*send(SendParameters{
          to: self.admin,
          value: 0,
          mode: SendRemainingValue + SendIgnoreErrors,
          bounce: false,
          body: beginCell().storeAddress(sender()).storeRef(msg.asCell()).endCell()
      });*/
  }
}
