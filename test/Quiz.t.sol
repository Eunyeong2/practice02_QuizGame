// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Quiz.sol";

contract QuizTest is Test {
    Quiz public quiz;
    uint quiz_num;
    address user1 = address(1337);
    Quiz.Quiz_item q1;

    function setUp() public {
       vm.deal(address(this), 100 ether);
       quiz = new Quiz();
       address(quiz).call{value: 5 ether}("");
       q1 = quiz.getQuiz(1);
    }

    function testAddQuizACL() public {
        uint quiz_num_before = quiz.getQuizNum();
        Quiz.Quiz_item memory q;
        q.id = quiz_num_before + 1;
        q.question = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
        q.answer = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB";
        q.min_bet = 1 ether;
        q.max_bet = 2 ether;
        vm.prank(address(1)); //message sender같은 역할을 실체가 아니라 테스트를 위해서 만든 것. (마치 호출한 것처럼)
        vm.expectRevert();
        quiz.addQuiz(q);
    }

    function testGetQuizSecurity() public { //answer 검열 부분
        Quiz.Quiz_item memory q = quiz.getQuiz(1);
        assertEq(q.answer, ""); //퀴즈는 모든 사용자가 쿼리를 할 수 있는데, 답변은 아무나 쿼리를 하지 못하도록 막아 놓았는지 확인
    }

    function testAddQuizGetQuiz() public { //권한체크 부분
        uint quiz_num_before = quiz.getQuizNum();
        Quiz.Quiz_item memory q;
        q.id = quiz_num_before + 1;
        q.question = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
        q.answer = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB";
        q.min_bet = 1 ether;
        q.max_bet = 2 ether;
        quiz.addQuiz(q);
        Quiz.Quiz_item memory q2 = quiz.getQuiz(q.id);
        q.answer = "";
        assertEq(abi.encode(q), abi.encode(q2));
    }

    function testBetToPlayMin() public {
        quiz.betToPlay{value: q1.min_bet}(1);
    }

    function testBetToPlay() public {
        quiz.betToPlay{value: (q1.min_bet + q1.max_bet) / 2}(1);
    }

    function testBetToPlayMax() public { //max를 betting 했을 때의 테스트
        quiz.betToPlay{value: q1.max_bet}(1);
    }

    function testFailBetToPlayMin() public {
        quiz.betToPlay{value: q1.min_bet - 1}(1);
    }

    function testFailBetToPlayMax() public { //max_bet+1을 하게 되면 fail이 되어야 함. 
        quiz.betToPlay{value: q1.max_bet + 1}(1);
    }

    function testMultiBet() public { //베팅은 한 번밖에 못 하는데 여러 번 했는지 테스트
        quiz.betToPlay{value: q1.min_bet}(1);
        quiz.betToPlay{value: q1.min_bet}(1);
        assertEq(quiz.bets(0, address(this)), q1.min_bet * 2); //1을 2번 베팅 -> 2 베팅과 동일
    }

    function testSolve1() public { // solveQuiz에서 오로지 return true만 하게 되면 Solve1은 pass
        quiz.betToPlay{value: q1.min_bet}(1);
        assertEq(quiz.solveQuiz(1, quiz.getAnswer(1)), true);
    }

    function testSolve2() public { //틀리면 상금 없고, 맞으면 상금 두 배.
        quiz.betToPlay{value: q1.min_bet}(1);
        uint256 prev_vb = quiz.vault_balance();
        uint256 prev_bet = quiz.bets(0, address(this));
        assertEq(quiz.solveQuiz(1, ""), false);
        uint256 bet = quiz.bets(0, address(this));
        assertEq(bet, 0);
        assertEq(prev_vb + prev_bet, quiz.vault_balance());
    }

    function testClaim() public {
        quiz.betToPlay{value: q1.min_bet}(1);
        quiz.solveQuiz(1, quiz.getAnswer(1));
        uint256 prev_balance = address(this).balance;
        quiz.claim();
        uint256 balance = address(this).balance;
        assertEq(balance - prev_balance, q1.min_bet * 2);
    }

    receive() external payable {}
}
