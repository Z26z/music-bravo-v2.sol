//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0);
        uint256 c = a / b;
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;
        return c;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);
        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

interface IERC20 {
    function transfer(address recipient, uint256 amount) external;

    function balanceOf(address account) external view returns (uint256);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external;
}

contract Auth {
    function SignedmessageHash(string memory _message)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    keccak256(abi.encodePacked(_message))
                )
            );
    }

    function recover(bytes32 _ethSignedMessageHash, bytes memory _signature)
        internal
        pure
        returns (address)
    {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);
        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory sig)
        private
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        require(sig.length == 65, "invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
        if (v < 27) {
            v += 27;
        }
        if (v != 27 && v != 28) {
            revert("err");
        } else {
            return (r, s, v);
        }
    }

    function stringToBytes32(string memory source)
        internal
        pure
        returns (bytes32 result)
    {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }
        assembly {
            result := mload(add(source, 32))
        }
    }
}

contract ERC20 {
    using SafeMath for uint256;

    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public owner_count;

    mapping(uint256 => address) public owner_list;
    mapping(address => bool) public owner_status;
    mapping(address => uint256) public _balances;
    mapping(address => mapping(address => uint256)) internal _allowed;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    uint256 internal _totalSupply;

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address owner) public view returns (uint256) {
        return _balances[owner];
    }

    function allowance(address owner, address spender)
        public
        view
        returns (uint256)
    {
        return _allowed[owner][spender];
    }

    function transfer(address to, uint256 value) public returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public returns (bool) {
        _allowed[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public returns (bool) {
        require(_allowed[from][msg.sender] >= value);
        _allowed[from][msg.sender] = _allowed[from][msg.sender].sub(value);
        _transfer(from, to, value);
        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal {
        require(to != address(0));
        _balances[from] = _balances[from].sub(value);
        _balances[to] = _balances[to].add(value);

        if (owner_status[from] == false) {
            owner_status[from] = true;
            owner_list[owner_count] = from;
            owner_count += 1;
        }

        if (owner_status[to] == false) {
            owner_status[to] = true;
            owner_list[owner_count] = to;
            owner_count += 1;
        }
        emit Transfer(from, to, value);
    }
}

contract MusicBrova_Reward is ERC20, Auth {
    using SafeMath for uint256;
    address public admin = msg.sender;
    address[] public rightsowner;
    string public metadata;

    mapping(bytes => bool) signatures;

    IERC20 public reward_token;

    event Initial(address[] owner, uint256[] _balance);
    event Rightsowner_history(address[] oldowner, address[] owner);
    event TransferPreSigned(
        address from,
        address to,
        address delegate,
        uint256 amount
    );

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _metadata,
        uint256 _total,
        address[] memory _rightsowner,
        address _token,
        address[] memory _tokenowner,
        uint256[] memory _balance
    ) {
        symbol = _symbol;
        name = _name;
        metadata = _metadata;
        decimals = 0;
        _totalSupply = _total;
        rightsowner = _rightsowner;
        metadata = _metadata;
        initial(_tokenowner, _balance);
        setrewardtoken(_token);
    }

    function initial(address[] memory _owner, uint256[] memory _balance)
        internal
    {
        for (uint256 i = 0; i < _owner.length; i++) {
            owner_status[_owner[i]] = true;
            owner_list[owner_count] = _owner[i];
            owner_count += 1;
            _balances[_owner[i]] = _balance[i];
        }
        emit Initial(_owner, _balance);
    }

    //設定新的所有權人
    function newrightsowner(address[] memory _newowner) public {
        require(msg.sender == admin);
        address[] storage old_rightsowner = rightsowner;
        rightsowner = _newowner;
        emit Rightsowner_history(old_rightsowner, _newowner);
    }

    //取得所有權人
    function getrightsowner()
        public
        view
        returns (address[] memory contract_rightsowner)
    {
        contract_rightsowner = rightsowner;
    }

    //驗證簽章傳送 transferPreSigned
    function transferPreSigned(
        bytes memory _signature,
        string memory _message,
        address _to,
        uint256 _amount
    ) public returns (bool) {
        require(_to != address(0));
        require(signatures[_signature] == false);
        bytes32 hashedTx = SignedmessageHash(_message);
        address from = recover(hashedTx, _signature);
        require(from != address(0));
        _transfer(from, _to, _amount);
        signatures[_signature] = true;
        emit TransferPreSigned(from, _to, msg.sender, _amount);
        return true;
    }

    //設定分潤的token
    function setrewardtoken(address _token) public {
        require(msg.sender == admin);
        reward_token = IERC20(address(_token));
    }

    //reward 分潤
    function reward(address[] memory _owner) public {
        uint256 _balance = reward_token.balanceOf(address(this));
        uint256 i;
        uint256 total;
        require(_balance != 0);
        total = count_total(_owner);
        for (i = 0; i < _owner.length; i++) {
            uint256 ownerreward;
            if (ERC20.owner_status[_owner[i]] == true) {
                ownerreward = _balance
                    .mul(ERC20._balances[_owner[i]])
                    .div(total);
                if (ownerreward != 0) {
                    reward_token.transfer(_owner[i], ownerreward);
                }
            }
        }
    }

    //count_total 計算被分潤者的總和
    function count_total(address[] memory _owner)public view returns (uint256 totals){
        for (uint256 i = 0; i < _owner.length; i++) {
            totals = totals.add(ERC20._balances[_owner[i]]);
        }
        return totals;
    }

    //deposit 取出reward_token
    function deposit() public {
        require(msg.sender == admin);
        uint256 _balance = reward_token.balanceOf(address(this));
        reward_token.transfer(admin, _balance);
    }
}