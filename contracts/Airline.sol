//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.7;
import "./Co2Consumer.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Airline is Ownable {
    
    string private s_name;
    Co2Consumer consumer;
    
    constructor(address _consumer) {
        consumer = Co2Consumer(_consumer);
    }

    function requestEmission(                
        string memory _from,
        string memory _to,
        uint _passengers,
        string memory _classFlight) external onlyOwner{
        consumer.requestCo2Emission(
            address(this),
            _from,
            _to,
            _passengers,
            _classFlight
        );
    }

    function getName() public view returns(string memory){
        return s_name;
    }

     

}
