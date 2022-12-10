import 'package:sbt_auth_dart/src/types/account.dart';

/// Remote share info
class RemoteShareInfo {
  /// Remote share info stored on server.
  RemoteShareInfo(this.address, this.remote, this.localAux, this.backupAux);

  /// Wallet address.
  final String address;

  /// Remote share
  final Share remote;

  /// Local aux
  final String localAux;

  /// Back up aux
  final String backupAux;
}

/// User info
class UserInfo {
  /// User info
  UserInfo({
    required this.userLoginName,
    required this.userID,
    required this.username,
    required this.avatar,
    required this.userLoginParams,
    required this.userLoginType,
    required this.publicKeyAddress,
    required this.userWhitelist,
  });

  /// User from map
  factory UserInfo.fromMap(Map<String, dynamic> map) {
    return UserInfo(
      userLoginName: map['userLoginName'] as String,
      userID: map['userID'] as String,
      username: map['username'] as String,
      avatar: map['avatar'] as String?,
      userLoginParams: map['userLoginParams'] as String,
      userLoginType: map['userLoginType'] as String,
      publicKeyAddress: map['publicKeyAddress'] as Map<String, dynamic>,
      userWhitelist: (map['userWhitelist'] ?? false) as bool,
    );
  }

  /// User login name
  String userLoginName;

  /// User id
  String userID;

  /// Username, email address or twitter name.
  String username;

  /// Avatar
  String? avatar;

  /// Login params
  String userLoginParams;

  /// Login type, google | twitter | facebook | email
  String userLoginType;

  /// User wallet address
  Map<String, dynamic> publicKeyAddress;

  /// Backup private key
  String? backupPrivateKey;

  /// White list switch
  bool userWhitelist;
}

/// Login QrCode status
class QrCodeStatus {
  /// QrCode status
  QrCodeStatus({
    required this.qrcodeName,
    required this.qrcodeClientID,
    required this.qrcodeExpireAt,
    required this.fail,
    required this.qrcodeEncryptedFragment,
    this.qrcodeAuthToken,
  });

  /// QrCode status from map
  factory QrCodeStatus.fromMap(Map<String, dynamic> map) {
    return QrCodeStatus(
      qrcodeName: (map['qrcodeName'] ?? '') as String,
      qrcodeClientID: (map['qrcodeClientID'] ?? '') as String,
      qrcodeExpireAt: (map['qrcodeExpireAt'] ?? '') as String,
      qrcodeAuthToken: (map['qrcodeAuthToken'] ?? '') as String,
      qrcodeEncryptedFragment: (map['qrcodeEncryptedFragment'] ?? '') as String,
      fail: (map['fail'] ?? false) as bool,
    );
  }

  /// QrCode name
  String qrcodeName;

  /// Clientid
  String qrcodeClientID;

  /// QrCode expire data
  String qrcodeExpireAt;

  ///  QrCode data
  String? qrcodeAuthToken;

  /// QrCode
  bool fail;

  /// qrcode EncryptedFragment
  String? qrcodeEncryptedFragment;
}

/// Device
class Device {
  /// Device
  Device({
    required this.deviceJoinTime,
    required this.userId,
    required this.deviceID,
    required this.deviceName,
  });

  /// Device from map
  factory Device.fromMap(Map<String, dynamic> map) {
    return Device(
      deviceJoinTime: (map['deviceJoinTime'] ?? '') as String,
      userId: (map['userId'] ?? '') as String,
      deviceID: (map['deviceID'] ?? '') as String,
      deviceName: (map['deviceName'] ?? '') as String,
    );
  }

  /// Join time
  String? deviceJoinTime;

  /// User id
  String? userId;

  /// Device id
  String? deviceID;

  /// Device name
  String? deviceName;
}

/// UserWhiteListItem
class UserWhiteListItem {
  /// UserWhiteListItem
  UserWhiteListItem({
    required this.userWhitelistName,
    required this.userWhitelistNetwork,
    required this.userWhitelistUserId,
    required this.userWhitelistID,
    required this.userWhitelistAddress,
  });

  /// UserWhiteListItem from map
  factory UserWhiteListItem.fromMap(Map<String, dynamic> map) {
    return UserWhiteListItem(
      userWhitelistName: (map['userWhitelistName'] ?? '') as String,
      userWhitelistNetwork: (map['userWhitelistNetwork'] ?? '') as String,
      userWhitelistUserId: (map['userWhitelistUserId'] ?? '') as String,
      userWhitelistID: (map['userWhitelistID'] ?? '') as String,
      userWhitelistAddress: (map['userWhitelistAddress'] ?? '') as String,
    );
  }

  /// Name
  String userWhitelistName;

  /// Network
  String userWhitelistNetwork;

  /// UserId
  String userWhitelistUserId;

  /// Id
  String userWhitelistID;

  /// Address
  String userWhitelistAddress;
}

/// Token info
class TokenInfo {

  /// Token info
  TokenInfo({
    required this.tokenInfoID,
    required this.tokenInfoName,
    required this.tokenInfoNetwork,
    required this.tokenInfoAddress,
    required this.tokenInfoSymbol,
    required this.tokenInfoIconUrl,
    required this.tokenInfoTokenType,
    required this.decimals,
    required this.description,
    required this.additionalInfo,
    required this.totalSupply,
  });

  /// TokenInfo from map
  factory TokenInfo.fromMap(Map<String, dynamic> map) {
    return TokenInfo(
      tokenInfoID: (map['tokenInfoID'] ?? '') as String,
      tokenInfoName: (map['tokenInfoName'] ?? '') as String,
      tokenInfoNetwork: (map['tokenInfoNetwork'] ?? '') as String,
      tokenInfoAddress: (map['tokenInfoAddress'] ?? '') as String,
      tokenInfoSymbol: (map['tokenInfoSymbol'] ?? '') as String,
      tokenInfoIconUrl: (map['tokenInfoIconUrl'] ?? '') as String,
      tokenInfoTokenType: (map['tokenInfoTokenType'] ?? '') as String,
      decimals: (map['decimals'] ?? 0) as int,
      description: (map['description'] ?? '') as String,
      additionalInfo: (map['additionalInfo'] ?? '') as String,
      totalSupply: (map['totalSupply'] ?? '') as String,
    );
  }

  /// Id
  String? tokenInfoID;

  /// Name
  String? tokenInfoName;

  /// Network
  String? tokenInfoNetwork;

  /// Address
  String? tokenInfoAddress;

  /// Symbol
  String? tokenInfoSymbol;

  /// Icon
  String? tokenInfoIconUrl;

  /// Type
  String? tokenInfoTokenType;

  /// Decimals
  int? decimals;

  /// Description
  String? description;

  /// Additional info
  String? additionalInfo;

  /// Total supply
  String? totalSupply;
}
