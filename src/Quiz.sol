// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract Quiz{
    struct Quiz_item {
      uint id;
      string question;
      string answer;
      uint min_bet;
      uint max_bet;
   }
    
    //storage 변수 2개
    mapping(uint => mapping(address => uint256)) public bets;
    uint public vault_balance;
    //owner 변수 추가
    address public owner;
    //퀴즈를 생성하는 매핑 추가
    mapping(uint => Quiz_item) public quizs; //quiz 변수 생성
    uint private quizQty;//quiz 개수
    mapping(address => uint256) public balances; //solveQuiz에서 금액을 저장할 변수

    constructor () {
        owner = msg.sender; //컨트랙트를 배포한 account 주소 설정
        Quiz_item memory q;
        q.id = 1;
        q.question = "1+1=?";
        q.answer = "2";
        q.min_bet = 1 ether;
        q.max_bet = 2 ether;
        addQuiz(q);
    } //quiz를 등록. 

    function addQuiz(Quiz_item memory q) public {
        require(msg.sender == owner); //컨트랙트를 배포한 소유주가 함수를 호출했는지 검증
        quizs[q.id] = q;
        quizQty += 1;
    }

    function getAnswer(uint quizId) public view returns (string memory){
        require(msg.sender == owner);
        return quizs[quizId].answer;
    }

    function getQuiz(uint quizId) public view returns (Quiz_item memory) {
        Quiz_item memory quiz = quizs[quizId]; //quizId에 해당하는 quiz
        quiz.answer = ""; //testGetQuizSecurity 통과 (answer 검열)
        return quiz;
    }

    //quiz의 id를 가져오는 함수 (랜덤하게?)
    function getQuizNum() public view returns (uint){
        return quizQty;
    }
    
    //play 하기 위해서 이더리움을 bet 하는 함수
    function betToPlay(uint quizId) public payable { //quiz 컨트랙트의 핵심 부분
        Quiz_item memory quiz = quizs[quizId]; //quizId를 이상한 걸 줘 버리면 0으로 가득찬 퀴즈가 나올 것
        uint256 betAmount = msg.value; //송금한 wei
        uint index = quizId - 1;
        require(betAmount >= quiz.min_bet); //min_bet 보다 큰 value가 베팅되었는가?
        require(betAmount <= quiz.max_bet); //max_bet 보다 큰 value가 배팅되었는가?
        bets[index][msg.sender] += betAmount; //bets라는 type이 mapping array. array의 각 요소가 매핑 address => uint256 으로 되어 있음. 퀴즈가 여러 개 있을 때, 퀴즈마다 사용자가 배팅을 할 수 있음. (각 퀴즈마다 배팅한 것들이 따로 기록되어야 함)
        //mapping 가져와서 msg.sender의 key를 참조해서 betAmount를 넣게 됨.
    }

    function solveQuiz(uint quizId, string memory ans) public returns (bool) {  
        Quiz_item memory quiz = quizs[quizId];
        uint index = quizId - 1; //FIXME index semantics? (testMultiBet에서 id를 0으로 주고 있음. (???????)

        // 답안이 맞는지 확인
        if (keccak256(bytes(quiz.answer)) == keccak256(bytes(ans))) { // (quiz.answer == ans) -> Compiler error!. hash 값을 비교하거나 bytes로 비교하는 식으로 진행해야 함
            //TODO reward
            balances[msg.sender] += bets[index][msg.sender]*2; //답이 맞으면 금액의 2배를 저장함.
            return true;
            } else{
                //TODO cancel bet
                vault_balance += bets[index][msg.sender];
                bets[index][msg.sender] = 0;
                return false;
            }    
    }

    function claim() public { //quiz가 맞았으면 베팅된 금액의 *2를 돌려줘야 함
        //solveQuiz와 claim은 다른 트랜잭션에서 호출될 수 있음. 
        //solveQuiz에서 답이 맞았는지 아닌지를 저장한 후, claim에서 그 금액만큼 가져와야 함. 
        uint256 amount = balances[msg.sender]; //상금 불러오기
        balances[msg.sender] = 0; //상금 reset
        //vault_balance -= amount;
        payable(msg.sender).transfer(amount); //송금

        //순서를 payable(msg.sender).call(value: amount)("") 로 변경해서 먼저 하고 vault_balance 를 하면 계속 claim을 호출할 수 있어서 돈복사를 할 수 있게 됨. reintracy 버그 (함수 호출을 계쏙 하는 것)
        // 방지하려면 먼저 amount가 있는지 체크한 후 날려버리고 send를 해야 함. (valance가 0이 되기 때문에 다시 claim이 호출되었을 때 아무 일도 일어나지 않음)
        // 즉,call 할 수 있는 구문이 먼저 나오게 되면 test는 넘어가겠지만 위험함.
    }

    receive() external payable {
        vault_balance += msg.value;
    }
}
