# [REG_PREDICT_COLLISION] Error 발생 원인 분석을 위한 테스트

# Edaplayground 링크
https://www.edaplayground.com/x/Y2rx

# 테스트 레지스터 맵
* 0x0번지에 **48bit크기** register인 "temp_reg" 하나만 존재
![image](https://user-images.githubusercontent.com/12408453/153202193-4e4b9bc0-8481-4c02-8c7e-e1a93293802b.png)


# 테스트 Block Diagram
* RAL Model과 연결된 apb_agent외에 **apb_agent가 하나 더 존재**
* apb_agent0: RAL에서 FRONTDOOR READ/WRITE 동작을 수행할 때 사용된다
* apb_agent1: test class에서 **uvm_sequence::start** task를 이용해 sequence를 실행시킬 때 사용된다 
![image](https://user-images.githubusercontent.com/12408453/153202387-ee8e006c-9ae3-46f1-bd24-5114a9215291.png)

# 테스트 동작 순서
![image](https://user-images.githubusercontent.com/12408453/153206118-3cd6600b-6d0f-4515-b972-f2293c77dc04.png)

1. ① test class에서 apb_agent1을 이용하여 temp_reg[31:0] 영역에 데이터를 Write한다.
2. apg_agent0와 apg_agent1 양쪽의 monitor에서 apb transaction을 감지한다.
3. ② predictor와 연결된 apb_agent0가 temp_reg write 내용을 TLM Interface를 이용해 전달한다.
4. predictor는 TLM 정보를 이용해 temp_reg에 매칭되는 model의 mirrored value를 update한다.\
predictor는 아직 write되지 않은 **상위 16bit가 이어서 write될 것으로 예상하고 monitoring하기 시작한다***
5. ③ RAL의 FRONTDOOR 동작을 이용해 temp_reg[31:0] 영역에 데이터를 Write한다.
6. ④ ***상위16bit가 아직 Write되지 않은 상태에서 하위 32bit에 대한 Write가 추가로 수행되면서 REG PREDICTOR COLLISION 에러가 발생한다***

# COLLISION 이후 UVM 동작 및 회피방법
아래 그림은 uvm_reg_predictor.svh파일의 COLLISION 메시지 출력 부분이다
![image](https://user-images.githubusercontent.com/12408453/153306547-b292a828-27db-48d6-a96e-4d978b6f82ee.png)
1. uvm_error message 출력
2. pending 중이던 transaction 제거

COLLISION이 발생하면 uvm_error가 무조건 발생하기 때문에 COLLISION이 발생하지 않도록 해야한다.\
COLLISION 회피방법은 2가지가 존재한다.
1. bus data width보다 큰 register를 RAL이 bus agent로 직접 write할 경우 항상 전체 영역을 write한다\
=> human error 발생 가능성이 존재함
2. RAL Model 작성 시 bus data width 크기로 register를 분할.
