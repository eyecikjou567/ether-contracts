/*
The MIT License (MIT)
Copyright (c) 2016 T. S.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), 
to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, 
and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS 
IN THE SOFTWARE.
*/
contract CoinJoin {
    /*
    How to use this contract:
    
    1. All participants meet up and agree on this transaction
    2. All participants put in their ether with their wallets.
    3. All participants then use different addresses (or the same if lazy) to propose pulling some value
    4. Once all participants agree, one begins the signing. By beginning the signing the contract is locked down. 
        No more proposals can be made and no ether stored as input.
    4.1. After the first Sign() Call, each participant should check the state of the contract if all data is correct.
    4.2. If any data is incorrect any of the signee's can call the Kill() Function to end the contract.
    5. All particpating addresses must call the Sign() function to agree on the state of the contract
    6. Once everyone has signed, the output addresses can begin pulling their share.
    7. The contract creator kills the contract and receives and remaining ether.
    */
    mapping (address => uint256) public inputs;
    mapping (address => uint256) public outputs;
    mapping (address => bool) public hasSigned;
    
    uint256 totalValue;
    //Discrepancy is used to ensure that nothing is left over in the contract
    uint256 discrepancyValue;
    //Number of signatures remaining
    uint256 signaturesRemaining;
    
    address public backpayAddress;
    
    //Indicates if the contract is dead
    bool public dead;
    bool public beginSigning;
    
    event BeganSigning();
    event FinishedSigning();
    
    //Is the sender part of the contract?
    modifier signee() {
        if (inputs[msg.sender] == 0) {
            throw;
        }
        if (outputs[msg.sender] == 0) {
            throw;
        }
    }
    
    //Allow only addresses that have not signed
    modifier notSigned() {
        if (hasSigned[msg.sender]) {
            throw;
        }
    }
    
    //Allow call only on non-dead contracts
    modifier notDead() {
        if (dead) {
            throw;
        }
    }
    
    //Is the contract signed?
    modifier signed() {
        if (signaturesRemaining > 0) {
            throw;
        }
    }
    
    //Is the contract in the process of signing?
    modifier signing() {
        if (!beginSigning) {
            throw;
        }
    }
    
    //Is the contract still open (not signed by anyone)?
    modifier open() {
        if (beginSigning) {
            throw;
        }
    }
    
    //The creator of the contract gets any leftover values from failed transactions.
    function CoinJoin ( ) {
        backpayAddress = msg.sender;
    }
    
    //Store some ether in the contract.
    function StoreValue ( ) notDead open {
        inputs[msg.sender] = msg.value;
        totalValue += msg.value;
        discrepancyValue += msg.value;
        signaturesRemaining++;
    }
    
    //Pull out of the contract
    function PullValue ( ) {
        if (dead || !beginSigning) {
            msg.sender.send(inputs[msg.sender]);
            discrepancyValue -= inputs[msg.sender];
            inputs[msg.sender] = 0;
            signaturesRemaining--;
        }
    }
    
    //Propose to get some value out of the contract
    function ProposeGetValue ( uint256 value ) notDead open {
        outputs[msg.sender] = value;
        signaturesRemaining++;
    }
    
    //Pull a proposal from the contract
    function PullProposal ( ) {
        if (msg.gas < 100000) {
            throw;
        }
        msg.sender.send(outputs[msg.sender]);
        discrepancyValue -= outputs[msg.sender];
        outputs[msg.sender] = 0;
        signaturesRemaining--;
    }
    
    //Get a proposal from the contract once it's signed.
    function GetValue ( ) signed {
        msg.sender.send(outputs[msg.sender]);
        totalValue -= outputs[msg.sender];
        outputs[msg.sender] = 0;
    }
    
    //The sender signs the contract only if they are either an input or output.
    //If all participants have signed, the contract is closed.
    //Signing can begin once the discrepancyValue is 0.
    function Sign ( ) notDead signee notSigned {
        if (discrepancyValue > 0) {
            throw;
        }
        if (!beginSigning) {
            BeganSigning();
            beginSigning = true;
        }
        signaturesRemaining--;
        if (signaturesRemaining == 0) {
            FinishedSigning();
        }
    }
    
    //Anyone who has not signed the contract can kill it.
    function CancelContract ( ) notDead signee notSigned {
        dead = true;
    }
    
    //Only works if all participants have claimed their ether or pulled out.
    //The contract need not be dead for this.
    function BackPay ( ) {
        if (msg.sender == backpayAddress && (signaturesRemaining == 0 || totalValue == 0)) {
            suicide(backpayAddress);
        }
    }
}
