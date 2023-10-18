import "@stdlib/deploy";

/*
  TASK 4 - NFT locker
  Implement a smart contract that will lock NFT for a period of time specified by the owner.
  Smart conrtact should contain logic to process following messages and getters: 

  Messages: 
  * OwnershipAssigned
   - Recives nft + time (in a forwardPayload message as uint32) for which this nft will be locked + address of the sender of the nft (prevOwner).
   - If the smart contract already holds an nft then return the incoming nft back to the sender
  * NftWithdrawal
   - Request withdrawal of the locked nft
   - If sender is not the owner (that came from OwnershipAssigned as prevOwner address) then throw "Invalid sender" 
   - If time has not passed then send message back to the sender with the comment "NFT is still locked" according to the TON's "message with text comment" standard 
   - Otherwise (all good) send the locked nft back to the owner with all the remaining TON balance
   Note that the order of checks is important
   (in case: "sender is not the owner" and "time has not passed" at the same time, "Invalid sender" error takes priority)

  Getters:
  * time
   - get how much lock time is left
  * nft
   - get the address of the locked nft 
  * owner
   - get the owner of the locked nft (that came from OwnershipAssigned as prevOwner)
*/

/*
  TASK 4 - NFT 록커
  NFT를 소유자가 지정한 기간 동안 잠글 수 있는 스마트 컨트랙트을 구현해야 합니다.
  이 스마트 계약은 다음과 같은 메시지와 게터를 처리하는 로직을 포함해야 합니다.
  
  Messages:
  * OwnershipAssigned
    - NFT, 해당 NFT가 잠길 기간으로 지정된 시간(forwardPayload message에서 unint32로 전송), NFT 송신자(prevOwner)의 주소를 수신
    - 스마트 컨트랙트가 이미 NFT를 보유하고 있다면 수신된 NFT를 발신자에게 반환합니다.
  * NftWithdrawal
    - 잠긴 NFT를 인출하도록 요청합니다.
    - 보낸 사람이 소유자가 아닌 경우("OwnershipAssigned"에서 prevOwner 주소로 전송된 것과 다른 경우) "Invalid sender" 오류를 발생시킵니다.
    - 시간이 경과하지 않았다면 TON의 "message with text comment" 표준에 따라 "NFT is still locked"라는 코멘트를 포함하여 발신자에게 메시지를 보냅니다.
    - 그렇지 않으면(모든 것이 정상이면) 잠긴 NFT를 소유자에게 모든 남은 TON 잔액과 함께 반환합니다.
    참고: 체크의 순서가 중요합니다("sender is not the owner"와 "time has not passed"라는 조건이 동시에 해당되는 경우 "Invalid sender" 오류가 우선적으로 적용됩니다).

  Getters:
  * time
    - 잠금 시간이 얼마나 남았는지 가져옵니다.
  * nft
    - 잠긴 NFT의 주소를 가져옵니다.
  * owner
    - 잠긴 NFT의 소유자를 가져옵니다("OwnershipAssigned"에서 prevOwner로 전송된 값).
*/

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

message NftWithdrawal {
  queryId: Int as uint64;
  nftAddress: Address;
}

contract Task4 with Deployable {
  seed: Int as uint128;
  nftLockTime: Int = 0;
  nftAddress: Address? = null;
  nftOwner: Address? = null;
  
  init(seed: Int) {
    self.seed = seed; // 하나의 admin 에서 여러 개의 스마트 컨트랙트 복사본을 배포해야 함
  }

  receive(msg: OwnershipAssigned) {
    if (self.nftAddress != null && self.nftOwner != null && self.nftLockTime != 0) {
      send(SendParameters{
        to: sender(),
        value: 0,
        mode: SendRemainingValue + SendIgnoreErrors,
        body: Transfer {
          queryId: 0,
          newOwner: msg.prevOwner,
          responseDestination: myAddress(),
          customPayload: null,
          forwardAmount: ton("0.01"),
          forwardPayload: emptySlice()
        }.toCell()
      });
    } else {
      self.nftLockTime = msg.forwardPayload.loadUint(32);
      self.nftAddress = sender();
      self.nftOwner = msg.prevOwner;
    }
  }

  receive(msg: NftWithdrawal) {
    require(self.nftLockTime > 0, "Invalid time");
    require(sender() == self.nftOwner, "Invalid sender");

    if (self.nftLockTime > now()) {
      send(SendParameters{
        to: sender(),
        value: 0,
        mode: SendRemainingValue + SendIgnoreErrors,
        body: "NFT is still locked".asComment()
      });   
    } else {
      send(SendParameters{
        to: sender(),
        value: 0,
        mode: SendRemainingValue + SendIgnoreErrors,
        body: Transfer {
          queryId: 0,
          newOwner: self.nftOwner!!,
          responseDestination: myAddress(),
          customPayload: null,
          forwardAmount: ton("0.01"),
          forwardPayload: emptySlice()
        }.toCell()
      });
      self.nftLockTime = 0;
      self.nftAddress = null;
      self.nftOwner = null;
    }
  }

  get fun time(): Int {
    return self.nftLockTime;
  }

  get fun nft(): Address? {
    return self.nftAddress;
  }

  get fun owner(): Address? {
    return self.nftOwner;
  }
}