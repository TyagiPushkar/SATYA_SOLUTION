import 'package:flutter/material.dart';

class AddCustomerFormController {
  // 1. Basic Information
  final customerNameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final fileCtrl = TextEditingController(text: 'No file chosen');

  // 2. Location Details
  final locationCtrl = TextEditingController();
  final districtCtrl = TextEditingController();
  final stateNameCtrl = TextEditingController();
  final subStateNameCtrl = TextEditingController();
  final pincodeCtrl = TextEditingController();

  // 3. Branch & Center Details
  final branchCodeCtrl = TextEditingController();
  final branchCtrl = TextEditingController();
  final centerNameCtrl = TextEditingController();
  final centerCodeCtrl = TextEditingController();

  // 4. Loan & Financial Details
  final loanTypeCtrl = TextEditingController();
  final loanNoCtrl = TextEditingController();
  final oldLoanNoCtrl = TextEditingController();
  final oldCustomerNoCtrl = TextEditingController();
  final cycleCtrl = TextEditingController();
  final loanDisbDateCtrl = TextEditingController();
  final loanAmountCtrl = TextEditingController();
  final osPrinCtrl = TextEditingController();
  final osIntCtrl = TextEditingController();
  final parCtrl = TextEditingController();
  final odPrinCtrl = TextEditingController();
  final odIntCtrl = TextEditingController();
  final totalDueAmtCtrl = TextEditingController();
  final totalPrinCollCtrl = TextEditingController();
  final totalIntCollCtrl = TextEditingController();
  final irrRateCtrl = TextEditingController();
  final noOfInstallmentCtrl = TextEditingController();
  final lastDueDateCtrl = TextEditingController();
  final lastPaidTrxDateCtrl = TextEditingController();
  final dpdCtrl = TextEditingController();
  final paidInstNoCtrl = TextEditingController();
  final loanStatusCtrl = TextEditingController();
  final installmentAmountCtrl = TextEditingController();
  final maturityDateCtrl = TextEditingController();
  final preClosureAmtCtrl = TextEditingController();

  // 5. Other Details
  final spouseNameCtrl = TextEditingController();

  Map<String, dynamic> getPayload() {
    return {
      "name": customerNameCtrl.text,
      "email": emailCtrl.text,
      "phone": phoneCtrl.text,
      "owner": "1",
      "location": locationCtrl.text,
      "district": districtCtrl.text,
      "state": stateNameCtrl.text,
      "sub_state": subStateNameCtrl.text,
      "branch_code": branchCodeCtrl.text,
      "branch": branchCtrl.text,
      "center": centerNameCtrl.text,
      "center_code": centerCodeCtrl.text,
      "loanType": loanTypeCtrl.text,
      "loanNo": loanNoCtrl.text,
      "oldLoanNo": oldLoanNoCtrl.text,
      "oldCustomerNo": oldCustomerNoCtrl.text,
      "image": (fileCtrl.text != 'No file chosen' && fileCtrl.text.isNotEmpty)
          ? fileCtrl.text
          : "https://example.com/images/default.jpg",
      "cycle": cycleCtrl.text,
      "loanDisbDate": loanDisbDateCtrl.text,
      "loanAmount": loanAmountCtrl.text,
      "os_principal": osPrinCtrl.text,
      "os_interest": osIntCtrl.text,
      "par": parCtrl.text,
      "od_principal": odPrinCtrl.text,
      "od_interest": odIntCtrl.text,
      "totalDueAmount": totalDueAmtCtrl.text,
      "total_principal_collectible": totalPrinCollCtrl.text,
      "total_interest_collectible": totalIntCollCtrl.text,
      "irrRate": irrRateCtrl.text,
      "noOfInstallment": noOfInstallmentCtrl.text,
      "lastDueDate": lastDueDateCtrl.text,
      "lastPaidTrxDate": lastPaidTrxDateCtrl.text,
      "dpd": dpdCtrl.text,
      "paidInstNo": paidInstNoCtrl.text,
      "loanStatus": loanStatusCtrl.text,
      "spouseName": spouseNameCtrl.text,
      "installmentAmount": installmentAmountCtrl.text,
      "maturityDate": maturityDateCtrl.text,
      "pincode": pincodeCtrl.text,
      "preClosureAmt": preClosureAmtCtrl.text,
    };
  }

  void dispose() {
    customerNameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    fileCtrl.dispose();
    locationCtrl.dispose();
    districtCtrl.dispose();
    stateNameCtrl.dispose();
    subStateNameCtrl.dispose();
    pincodeCtrl.dispose();
    branchCodeCtrl.dispose();
    branchCtrl.dispose();
    centerNameCtrl.dispose();
    centerCodeCtrl.dispose();
    loanTypeCtrl.dispose();
    loanNoCtrl.dispose();
    oldLoanNoCtrl.dispose();
    oldCustomerNoCtrl.dispose();
    cycleCtrl.dispose();
    loanDisbDateCtrl.dispose();
    loanAmountCtrl.dispose();
    osPrinCtrl.dispose();
    osIntCtrl.dispose();
    parCtrl.dispose();
    odPrinCtrl.dispose();
    odIntCtrl.dispose();
    totalDueAmtCtrl.dispose();
    totalPrinCollCtrl.dispose();
    totalIntCollCtrl.dispose();
    irrRateCtrl.dispose();
    noOfInstallmentCtrl.dispose();
    lastDueDateCtrl.dispose();
    lastPaidTrxDateCtrl.dispose();
    dpdCtrl.dispose();
    paidInstNoCtrl.dispose();
    loanStatusCtrl.dispose();
    installmentAmountCtrl.dispose();
    maturityDateCtrl.dispose();
    preClosureAmtCtrl.dispose();
    spouseNameCtrl.dispose();
  }
}
