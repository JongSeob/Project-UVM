# Chipverify_regModel_2_Complete


## 예제 edaplayground
* https://www.edaplayground.com/x/XDZB

## 원본 소스코드 출처
* https://www.chipverify.com/uvm/uvm-register-model-example

## 예제 레지스터맵
<img src="https://www.chipverify.com/images/uvm/design.png" alt="레지스터 구조 이미지" />

## 예제 UML Class Diagram

**파란색 배경 = uvm basic class**\
**주황색 배경 = Register Abstract Layer 관련 Class**\
**하얀색 배경 = apb agent 관련 Class**
![image](https://user-images.githubusercontent.com/12408453/150986090-d6cb7513-77fd-4297-901f-844331a6ae03.png)


## 예제 UVCs Block Diagram
* 블록에 적힌 이름은 기본적으로 Class Name임.
* 이름 뒤에 괄호 () 추가한 것은 가독성을 위해 부모 uvm class를 표시한 것\
  (uvm_reg or uvm_reg_map or uvm_reg_block)
* 빨강, 파랑 화살표는 각각 Frontdoor, monitor&predictor 동작에서의 ***item handle 전달 방향***을 나타냄\
  여기서 item은 sequence_item, reg_item, reg_bus_op 모두를 통칭.
![image](https://user-images.githubusercontent.com/12408453/154830114-d381b0c7-87da-4918-86dd-d413e77f6894.png)
