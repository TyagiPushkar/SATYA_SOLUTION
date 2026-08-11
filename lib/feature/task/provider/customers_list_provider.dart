import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';
import '../../../core/api/api_endpoints.dart';

class CustomerModel {
  final String id;
  final String customerId;
  final String name;
  final String email;
  final String phone;
  final String slug;
  final String ownerName;
  final String location;
  final String district;
  final String state;
  final String subState;
  final String branchCode;
  final String branch;
  final String center;
  final String centerCode;
  final String loanType;
  final String loanNo;
  final String oldLoanNo;
  final String oldCustomerNo;
  final String image;
  final String cycle;
  final String loanDisbDate;
  final String loanAmount;
  final String osPrincipal;
  final String osInterest;
  final String par;
  final String odPrincipal;
  final String odInterest;
  final String totalDueAmount;
  final String totalPrincipalCollectible;
  final String totalInterestCollectible;
  final String irrRate;
  final String noOfInstallment;
  final String lastDueDate;
  final String lastPaidTrxDate;
  final String dpd;
  final String paidInstNo;
  final String loanStatus;
  final String spouseName;
  final String installmentAmount;
  final String maturityDate;
  final String pincode;
  final String preClosureAmt;
  final String closedDate;
  final String createdByName;
  final String updatedByName;
  final String createdAt;
  final String updatedAt;
  final Map<String, dynamic> rawJson;

  CustomerModel({
    required this.id,
    required this.customerId,
    required this.name,
    required this.email,
    required this.phone,
    required this.slug,
    required this.ownerName,
    required this.location,
    required this.district,
    required this.state,
    required this.subState,
    required this.branchCode,
    required this.branch,
    required this.center,
    required this.centerCode,
    required this.loanType,
    required this.loanNo,
    required this.oldLoanNo,
    required this.oldCustomerNo,
    required this.image,
    required this.cycle,
    required this.loanDisbDate,
    required this.loanAmount,
    required this.osPrincipal,
    required this.osInterest,
    required this.par,
    required this.odPrincipal,
    required this.odInterest,
    required this.totalDueAmount,
    required this.totalPrincipalCollectible,
    required this.totalInterestCollectible,
    required this.irrRate,
    required this.noOfInstallment,
    required this.lastDueDate,
    required this.lastPaidTrxDate,
    required this.dpd,
    required this.paidInstNo,
    required this.loanStatus,
    required this.spouseName,
    required this.installmentAmount,
    required this.maturityDate,
    required this.pincode,
    required this.preClosureAmt,
    required this.closedDate,
    required this.createdByName,
    required this.updatedByName,
    required this.createdAt,
    required this.updatedAt,
    required this.rawJson,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    String str(dynamic val) => val?.toString() ?? '';
    String cap(dynamic val) {
      final s = str(val);
      if (s.trim().isEmpty) return s;
      return s.replaceAllMapped(
        RegExp(r'\b[a-z]'),
        (match) => match.group(0)!.toUpperCase(),
      );
    }

    final ownerMap = json['owner'] is Map ? json['owner'] as Map : {};
    final createdByMap = json['createdBy'] is Map ? json['createdBy'] as Map : {};
    final updatedByMap = json['updatedBy'] is Map ? json['updatedBy'] as Map : {};

    return CustomerModel(
      id: str(json['id'] ?? json['_id']),
      customerId: str(json['customer_id']),
      name: cap(json['name']),
      email: str(json['email']),
      phone: str(json['phone']),
      slug: str(json['slug']),
      ownerName: cap(ownerMap['name']),
      location: cap(json['location']),
      district: cap(json['district']),
      state: cap(json['state']),
      subState: cap(json['sub_state']),
      branchCode: str(json['branch_code']),
      branch: cap(json['branch']),
      center: cap(json['center']),
      centerCode: str(json['center_code']),
      loanType: cap(json['loanType']),
      loanNo: str(json['loanNo']),
      oldLoanNo: str(json['oldLoanNo']),
      oldCustomerNo: str(json['oldCustomerNo']),
      image: str(json['image']),
      cycle: str(json['cycle']),
      loanDisbDate: str(json['loanDisbDate']),
      loanAmount: str(json['loanAmount']),
      osPrincipal: str(json['os_principal']),
      osInterest: str(json['os_interest']),
      par: str(json['par']),
      odPrincipal: str(json['od_principal']),
      odInterest: str(json['od_interest']),
      totalDueAmount: str(json['totalDueAmount']),
      totalPrincipalCollectible: str(json['total_principal_collectible']),
      totalInterestCollectible: str(json['total_interest_collectible']),
      irrRate: str(json['irrRate']),
      noOfInstallment: str(json['noOfInstallment']),
      lastDueDate: str(json['lastDueDate']),
      lastPaidTrxDate: str(json['lastPaidTrxDate']),
      dpd: str(json['dpd']),
      paidInstNo: cap(json['paidInstNo']),
      loanStatus: cap(json['loanStatus']),
      spouseName: cap(json['spouseName']),
      installmentAmount: str(json['installmentAmount']),
      maturityDate: str(json['maturityDate']),
      pincode: str(json['pincode']),
      preClosureAmt: str(json['preClosureAmt']),
      closedDate: str(json['closedDate']),
      createdByName: cap(createdByMap['name']),
      updatedByName: cap(updatedByMap['name']),
      createdAt: str(json['createdAt']),
      updatedAt: str(json['updatedAt']),
      rawJson: json,
    );
  }
}

class CustomerScreenState {
  final List<CustomerModel> customers;
  final int currentPage;
  final int totalPages;
  final bool isLoading;
  final bool isLoadMore;
  final String search;

  CustomerScreenState({
    this.customers = const [],
    this.currentPage = 1,
    this.totalPages = 1,
    this.isLoading = false,
    this.isLoadMore = false,
    this.search = '',
  });

  CustomerScreenState copyWith({
    List<CustomerModel>? customers,
    int? currentPage,
    int? totalPages,
    bool? isLoading,
    bool? isLoadMore,
    String? search,
  }) {
    return CustomerScreenState(
      customers: customers ?? this.customers,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      isLoading: isLoading ?? this.isLoading,
      isLoadMore: isLoadMore ?? this.isLoadMore,
      search: search ?? this.search,
    );
  }
}

class CustomerScreenNotifier extends Notifier<CustomerScreenState> {
  @override
  CustomerScreenState build() {
    return CustomerScreenState();
  }

  Future<void> fetchCustomers({bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(isLoading: true, currentPage: 1, customers: []);
    } else {
      if (state.isLoadMore || state.isLoading) return;
      if (state.currentPage >= state.totalPages) return;
      state = state.copyWith(isLoadMore: true);
    }

    try {
      final apiService = ref.read(apiServiceProvider);
      final pageToLoad = refresh ? 1 : state.currentPage + 1;

      final Map<String, dynamic> queryParameters = {
        'page': pageToLoad,
        'limit': 10,
      };
      if (state.search.isNotEmpty) {
        queryParameters['search'] = state.search;
      }

      final response = await apiService.get(ApiEndpoints.getCustomers, queryParameters: queryParameters);
      final dynamic responseData = response.data;
      Map<String, dynamic> responseMap;
      if (responseData is String) {
        responseMap = jsonDecode(responseData) as Map<String, dynamic>;
      } else if (responseData is Map) {
        responseMap = Map<String, dynamic>.from(responseData);
      } else {
        responseMap = {};
      }

      final isSuccess = responseMap['success'] == true || responseMap['statusCode'] == 200;
      if (isSuccess) {
        final data = responseMap['data'] ?? {};
        final List<dynamic> customersData = (data is Map ? data['customers'] : null) ?? [];
        final int totalPages = (data is Map ? data['totalPages'] : null) ?? 1;
        final int currentPage = (data is Map ? data['currentPage'] : null) ?? pageToLoad;

        final newCustomers = customersData
            .map((e) => CustomerModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

        final fullList = refresh ? newCustomers : [...state.customers, ...newCustomers];

        state = state.copyWith(
          customers: fullList,
          currentPage: currentPage,
          totalPages: totalPages,
          isLoading: false,
          isLoadMore: false,
        );
      } else {
        state = state.copyWith(isLoading: false, isLoadMore: false);
      }
    } catch (e) {
      debugPrint("Error fetching customers: $e");
      state = state.copyWith(isLoading: false, isLoadMore: false);
    }
  }

  void setSearch(String search) {
    state = state.copyWith(search: search);
    fetchCustomers(refresh: true);
  }
}

final customerScreenProvider = NotifierProvider<CustomerScreenNotifier, CustomerScreenState>(() {
  return CustomerScreenNotifier();
});

final customersListProvider = FutureProvider.autoDispose<List<CustomerModel>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  final response = await apiService.get(ApiEndpoints.getCustomers);
  debugPrint("getCustomers raw data type: ${response.data.runtimeType}");
  debugPrint("getCustomers raw response: ${response.data}");
  final dynamic responseData = response.data;
  Map<String, dynamic> responseMap;
  if (responseData is String) {
    responseMap = jsonDecode(responseData) as Map<String, dynamic>;
  } else if (responseData is Map) {
    responseMap = Map<String, dynamic>.from(responseData);
  } else {
    responseMap = {};
  }
  final isSuccess = responseMap['success'] == true || responseMap['statusCode'] == 200;
  if (isSuccess) {
    final data = responseMap['data'];
    final List<dynamic> customersData = (data is Map ? data['customers'] : null) ?? [];
    debugPrint("Parsed customers count: ${customersData.length}");
    return customersData.map((e) => CustomerModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  } else {
    throw Exception(responseMap['message'] ?? 'Failed to fetch customers');
  }
});

