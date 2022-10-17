pragma solidity 0.8.7;

interface ICo2Consumer {
    struct Co2Emission {
        address ctrRAirline;
        address airlineContract;
        uint256 roundId;
        uint256 co2Amount;
        uint256 startedAt;
        uint256 finishedAt;
        bytes32 requestId;
    }

    function requestCo2Emission(
        address _airlineContract,
        string memory _from,
        string memory _to,
        uint256 _passengers,
        string memory _classFlight
    ) external returns (bytes32 requestId);

    function getLastEmissionByAirline(address _airlineContract)
        external
        view
        returns (
            uint ctrRAirline,
            address airlineContract,
            uint256 roundId,
            uint256 co2Amount,
            uint256 startedAt,
            uint256 finishedAt,
            bytes32 requestId
        );
}
