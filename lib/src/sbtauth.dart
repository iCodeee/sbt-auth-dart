// ignore_for_file: constant_identifier_names, avoid_dynamic_calls

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:eth_sig_util/util/utils.dart';
import 'package:eventsource/eventsource.dart';
import 'package:flutter/cupertino.dart';
import 'package:mpc_dart/multi_mpc_dart.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';
import 'package:sbt_auth_dart/src/api.dart';
import 'package:sbt_auth_dart/src/core/aptos_singer.dart';
import 'package:sbt_auth_dart/src/core/bitcoin_signer.dart';
import 'package:sbt_auth_dart/src/core/near_signer.dart';
import 'package:sbt_auth_dart/src/core/solana_signer.dart';
import 'package:sbt_auth_dart/src/core/tron_signer.dart';
import 'package:sbt_auth_dart/src/db_util.dart';
import 'package:url_launcher/url_launcher.dart';

/// Develop app url
const DEVELOP_AUTH_URL = 'https://test-auth.safematrix.io';

/// Production app url
const PRODUCTION_AUTH_URL = 'https://auth.safematrix.io';

/// Login types
enum LoginType {
  /// Login with google account
  google,

  /// Login with facebook
  facebook,

  /// Login with email
  email,

  /// Login with twitter
  twitter,

  /// Login with apple
  apple,

  /// Login with phone
  phone,
}

/// Local type
enum LocaleType {
  /// en
  en_US,

  /// zh_cn
  zh_CN,

  /// zh_TW
  zh_TW
}

/// SbtAuth class
class SbtAuth {
  /// SBTAuth, you need to set your own custom scheme.
  SbtAuth({
    required this.developMode,
    required String clientId,
    required String scheme,
    String? url,
    Map<String, String>? rpcUrls,
  }) {
    _clientId = clientId;
    _scheme = scheme;
    _url = url;
    _rpcUrls = rpcUrls;
  }

  /// If you set developMode true, the use registered is on test site, can only
  /// access to testnet.
  late bool developMode;

  late String _clientId;
  late String _scheme;

  String? _url;

  /// Locale
  LocaleType locale = LocaleType.en_US;
  Map<String, String>? _rpcUrls;

  /// Loading stream
  StreamController<bool> loadingStreamController = StreamController.broadcast();

  /// Login stream
  StreamController<bool> loginStreamController = StreamController.broadcast();

  /// Login user
  UserInfo? get user => _user;

  UserInfo? _user;

  /// core
  AuthCore? get core => _core;

  AuthCore? _core;

  /// solana core
  AuthCore? get solanaCore => _solanaCore;

  AuthCore? _solanaCore;

  /// bitcoin core
  AuthCore? get bitcoinCore => _bitcoinCore;

  AuthCore? _bitcoinCore;

  /// bitcoin core
  AuthCore? get dogecoinCore => _dogecoinCore;

  AuthCore? _dogecoinCore;

  EventSource? _eventSource;

  /// solana singer
  SolanaSigner? get solanaSinger => _solanaCore == null
      ? null
      : SolanaSigner(
          _solanaCore!,
          _solanaUrl,
          _solanaNetwork,
        );

  /// bitcoin singer
  BitcoinSigner? get bitcoinSinger => _bitcoinCore == null
      ? null
      : BitcoinSigner(
          _bitcoinCore!,
          developMode,
          true,
          url: _url,
        );

  /// dogecoin singer
  BitcoinSigner? get dogecoinSinger => _dogecoinCore == null
      ? null
      : BitcoinSigner(
          _dogecoinCore!,
          developMode,
          false,
          url: _url,
        );

  /// Aptos singer
  AptosSigner? get aptosSigner => _aptosCore == null
      ? null
      : AptosSigner(
          _aptosCore!,
          developMode,
        );

  /// aptos core
  AuthCore? get aptosCore => _aptosCore;

  AuthCore? _aptosCore;

  /// Near singer
  NearSigner? get nearSigner => _nearCore == null
      ? null
      : NearSigner(
          isTestnet: developMode,
          core: nearCore!,
        );

  /// aptos core
  AuthCore? get nearCore => _nearCore;

  AuthCore? _nearCore;

  /// tron singer
  TronSigner? get tronSigner => _tronCore == null
      ? null
      : TronSigner(
          core: tronCore!,
          testNet: developMode,
          jRPCUrl: _rpcUrls?['tron_jrpc'] ?? 'https://api.shasta.trongrid.io',
          gRPCUrl: _rpcUrls?['tron_grpc'] ?? 'https://grpc.shasta.trongrid.io',
        );

  /// tron core
  AuthCore? get tronCore => _tronCore;

  AuthCore? _tronCore;

  /// Grant authorization listen controller
  StreamController<String> authRequestStreamController =
      StreamController.broadcast();

  String get _baseUrl => developMode ? DEVELOP_BASE_URL : PRODUCTION_BASE_URL;

  String get _solanaUrl =>
      developMode ? DEVELOP_SOLANA_URL : PRODUCTION_SOLANA_URL;

  String get _solanaNetwork => developMode ? 'solana_devnet' : 'solana';

  Timer? _timer;

  /// token
  String get token => DBUtil.tokenBox.get(TOKEN_KEY) ?? '';

  /// SBTAuth api
  SbtAuthApi get api {
    if (token == '') throw SbtAuthException('User not logined');
    return SbtAuthApi(
      baseUrl: _baseUrl,
      token: token,
      local: _getLocale(locale),
    );
  }

  /// provider
  SbtAuthProvider? get provider => core == null
      ? null
      : SbtAuthProvider(
          signer: core!.signer,
          clientId: _clientId,
          isTestnet: developMode,
          url: _url,
          rpcUrls: _rpcUrls,
        );

  /// Init sbtauth hive
  static Future<void> initHive() async {
    await DBUtil.init();
  }

  /// check user
  Future<bool?> checkUser(String email, {String localLan = 'en-US'}) async {
    final res = await SbtAuthApi.queryUser(
      email,
      baseUrl: _baseUrl,
      localLan: localLan,
      clientID: _clientId,
    );
    return res;
  }

  /// check user
  Future<bool> userExist(
    String loginName,
    LoginType loginType, {
    String localLan = 'en-US',
  }) async {
    final res = await SbtAuthApi.userExist(
      loginName,
      loginType: loginType,
      baseUrl: _baseUrl,
      localLan: localLan,
      clientID: _clientId,
    );
    return res;
  }

  /// Init sbtauth
  Future<void> init({
    bool isLogin = false,
    SbtChain chain = SbtChain.EVM,
    bool create = true,
  }) async {
    _user = DBUtil.userBox.get('user');
    _user ??= await api.getUserInfo();
    if (_user == null) throw SbtAuthException('User not logined');
    await DBUtil.userBox.put('user', user);
    if (!create) {
      return;
    }
    if (_user!.publicKeyAddress[chain.name] == null) {
      final core = getCore(chain);
      final account = await core.generatePubKey(testnet: developMode);
      await DBUtil.auxBox.put(account.address, account.shares[2].extraData);
      await DBUtil.hashBox.put(
        account.address,
        bytesToHex(
          hashMessage(ascii.encode(jsonEncode(account.shares[2].toJson()))),
          include0x: true,
        ),
      );
      await api.uploadShares(
        account.shares,
        account.address,
        jsonEncode(AuthCore.getRemoteKeypair(account.shares[1]).toJson()),
        keyType: chain.name,
      );
      switch (chain) {
        case SbtChain.EVM:
          _core = core;
          user!.backupPrivateKey = account.shares[2].privateKey;
          break;
        case SbtChain.SOLANA:
          _solanaCore = core;
          break;
        case SbtChain.BITCOIN:
          _bitcoinCore = core;
          break;
        case SbtChain.DOGECOIN:
          _dogecoinCore = core;
          break;
        case SbtChain.APTOS:
          _aptosCore = core;
          break;
        case SbtChain.NEAR:
          _nearCore = core;
          break;
        case SbtChain.TRON:
          _tronCore = core;
          break;
      }
    } else {
      final remoteLocalShareInfo =
          await api.fetchRemoteShare(keyType: chain.name);
      final core = getCore(chain);
      final inited = await core.init(
        address: remoteLocalShareInfo.address,
        remote: remoteLocalShareInfo.remote,
        isTestnet: developMode,
      );
      if (!isLogin) {
        if (!inited) throw SbtAuthException('Init error');
      }
      if (inited) {
        switch (chain) {
          case SbtChain.EVM:
            _core = core;
            _core!.signModel = user!.whitelistSwitch;
            break;
          case SbtChain.SOLANA:
            _solanaCore = core;
            _solanaCore!.signModel = user!.whitelistSwitch;
            break;
          case SbtChain.BITCOIN:
            _bitcoinCore = core;
            _bitcoinCore!.signModel = user!.whitelistSwitch;
            break;
          case SbtChain.DOGECOIN:
            _dogecoinCore = core;
            _dogecoinCore!.signModel = user!.whitelistSwitch;
            break;
          case SbtChain.APTOS:
            _aptosCore = core;
            _aptosCore!.signModel = user!.whitelistSwitch;
            break;
          case SbtChain.NEAR:
            _nearCore = core;
            _nearCore!.signModel = user!.whitelistSwitch;
            break;
          case SbtChain.TRON:
            _tronCore = core;
            _tronCore!.signModel = user!.whitelistSwitch;
            break;
        }
        await DBUtil.auxBox.put(
          core.getAddress(isTestnet: developMode),
          remoteLocalShareInfo.backupAux,
        );
        await DBUtil.hashBox.put(
          core.getAddress(isTestnet: developMode),
          remoteLocalShareInfo.backupHash,
        );
      }
    }
    await _authRequestListener();
  }

  /// Get core
  AuthCore getCore(SbtChain chain) {
    return AuthCore(
      mpcUrl: MpcUrl(
        url: _baseUrl,
        get: 'user/forward:query:data',
        set: 'user/forward:data',
      ),
      signUrl: '$_baseUrl/user:sign',
      token: token,
      chain: chain,
    );
  }

  /// Timer cancel
  void timerCancel() {
    _timer?.cancel();
  }

  ///Reset password
  Future<void> resetPwd(
    String emailAddress,
    String authCode,
    String password, {
    String areaCode = '',
    String phoneNumber = '',
    LoginType loginType = LoginType.email,
  }) async {
    await SbtAuthApi.resetPassword(
      emailAddress,
      authCode,
      password,
      _baseUrl,
      _clientId,
      localLan: _getLocale(locale),
      areaCode: areaCode,
      phoneNumber: phoneNumber,
      loginType: loginType,
    );
  }

  /// Get device list
  Future<List<Device>> getDeviceList() async {
    final deviceList = await api.getUserDeviceList(_clientId);
    return deviceList;
  }

  /// Login
  Future<void> login(
    LoginType loginType, {
    String? email,
    String? areaCode,
    String? phone,
    String? code,
    String? password,
    String? captchaToken,
    bool create = true,
  }) async {
    assert(
      loginType != LoginType.email ||
          (loginType == LoginType.email &&
              email != null &&
              !(code == null && password == null)),
      'Password or code required if login with email',
    );
    assert(
      loginType != LoginType.phone ||
          (loginType == LoginType.phone &&
              phone != null &&
              !(code == null && password == null)),
      'Password or code required if login with phone',
    );
    String? token;
    if (loginType == LoginType.email || loginType == LoginType.phone) {
      token = await SbtAuthApi.userLogin(
        email: email,
        areaCode: areaCode,
        phone: phone,
        code: code,
        password: password,
        clientId: _clientId,
        baseUrl: _baseUrl,
        localLan: _getLocale(locale),
        captchaToken: captchaToken,
        loginType: loginType,
      );
    } else {
      final deviceName = await getDeviceName();
      final appUrl = developMode ? DEVELOP_AUTH_URL : PRODUCTION_AUTH_URL;
      final loginUrl =
          '''$appUrl?loginType=${loginType.name}&developMode=$developMode&scheme=$_scheme&deviceName=$deviceName&clientId=$_clientId''';
      unawaited(
        launchUrl(
          Uri.parse(loginUrl),
          mode: Platform.isAndroid
              ? LaunchMode.externalApplication
              : LaunchMode.platformDefault,
        ),
      );
      final completer = Completer<String?>();
      final appLinks = AppLinks();
      final linkSubscription = appLinks.uriLinkStream.listen((uri) {
        if (uri.toString().startsWith(_scheme)) {
          completer.complete(uri.queryParameters['token']);
        }
      });
      token = await completer.future;
      if (Platform.isIOS) {
        await closeInAppWebView();
      }
      await linkSubscription.cancel();
    }
    _timer?.cancel();
    if (loginType != LoginType.email) {
      loadingStreamController.add(true);
    }
    try {
      if (token == null) return;
      _saveToken(token);
      await DBUtil.userBox.delete('user');
      await init(isLogin: true, create: create);
    } catch (e) {
      rethrow;
    } finally {
      if (loginType != LoginType.email) {
        loadingStreamController.add(false);
      }
    }
  }

  /// Batch backup
  Future<void> batchBackup(
    String password,
    String email,
    String code, {
    String googleCode = '',
  }) async {
    final backupInfo = await getBackupData(password);
    await api.batchBackup(
      code,
      backupInfo,
      email,
      googleCode: googleCode,
    );
  }

  /// Logout
  void logout() {
    DBUtil.tokenBox.delete(TOKEN_KEY);
    DBUtil.userBox.delete('user');
    _user = null;
    _core = null;
    _solanaCore = null;
    _bitcoinCore = null;
    _dogecoinCore = null;
    _aptosCore = null;
    _eventSource?.client.close();
  }

  /// Approve auth request
  Future<String> approveAuthRequest(
    String deviceName, {
    SbtChain chain = SbtChain.EVM,
  }) async {
    var local = '';
    switch (chain) {
      case SbtChain.EVM:
        if (core == null) {
          throw SbtAuthException('Auth not inited');
        }
        local = core!.localShare!.privateKey;
        break;
      case SbtChain.SOLANA:
        if (solanaCore == null) {
          throw SbtAuthException('Solana auth not inited');
        }
        local = solanaCore!.localShare!.privateKey;
        break;
      case SbtChain.BITCOIN:
        if (bitcoinCore == null) {
          throw SbtAuthException('Bitcoin auth not inited');
        }
        local = bitcoinCore!.localShare!.privateKey;
        break;
      case SbtChain.DOGECOIN:
        if (dogecoinCore == null) {
          throw SbtAuthException('Dogecoin auth not inited');
        }
        local = dogecoinCore!.localShare!.privateKey;
        break;
      case SbtChain.APTOS:
        if (aptosCore == null) {
          throw SbtAuthException('Aptos auth not inited');
        }
        local = aptosCore!.localShare!.privateKey;
        break;
      case SbtChain.NEAR:
        if (nearCore == null) {
          throw SbtAuthException('Near auth not inited');
        }
        local = nearCore!.localShare!.privateKey;
        break;
      case SbtChain.TRON:
        if (tronCore == null) {
          throw SbtAuthException('Tron auth not inited');
        }
        local = tronCore!.localShare!.privateKey;
        break;
    }
    final password = StringBuffer();
    for (var i = 0; i < 6; i++) {
      password.write(Random().nextInt(9).toString());
    }
    final encrypted = await encryptMsg(local, password.toString());
    await api.approveAuthRequest(deviceName, encrypted, chain.name);
    return password.toString();
  }

  /// Get login QrCode
  Future<String> getLoginQrCode() async {
    final qrCodeId = await SbtAuthApi.getLoginQrcode(_baseUrl, _clientId);
    final password = StringBuffer();
    for (var i = 0; i < 6; i++) {
      password.write(Random().nextInt(9).toString());
    }
    final controller = StreamController<StreamResponse>();
    final completer = Completer<String?>();
    _queryWhetherSuccess(password.toString(), qrCodeId, controller)
        .listen((event) {
      if (event.data != null) {
        completer.complete(event.data);
      }
    });
    final dataMap = {'qrCodeId': qrCodeId, 'password': password.toString()};
    return jsonEncode(dataMap);
  }

  /// Get login with qrcode encrypted message
  Future<void> approveLoginWithQrCode(String qrcode) async {
    final qrcodeData = jsonDecode(qrcode) as Map;
    final password = qrcodeData['password'] as String?;
    final qrCodeId = qrcodeData['qrCodeId'] as String?;
    if (password == null || qrCodeId == null) {
      throw SbtAuthException('Invalid QrCode');
    }
    final status = await SbtAuthApi.getQrCodeStatus(_baseUrl, qrCodeId);
    // if (int.parse(status.qrcodeExpireAt) >=
    //     DateTime.now().millisecondsSinceEpoch) {
    //   throw SbtAuthException('QrCode expired');
    // }
    if (status.qrcodeAuthToken != null && status.qrcodeAuthToken != '') {
      throw SbtAuthException('QrCode used already');
    }
    if (core == null) throw SbtAuthException('Auth not inited');
    final local = <String, String?>{
      'clientId': _clientId,
      'evm': core!.localShare!.privateKey,
    };
    if (solanaCore == null) {
      await init(chain: SbtChain.SOLANA, isLogin: true);
    }
    if (solanaCore != null) {
      local['solana'] = solanaCore?.localShare?.privateKey;
    }
    if (bitcoinCore == null) {
      await init(chain: SbtChain.BITCOIN, isLogin: true);
    }
    if (bitcoinCore != null) {
      local['bitcoin'] = bitcoinCore?.localShare?.privateKey;
    }
    if (dogecoinCore == null) {
      await init(chain: SbtChain.DOGECOIN, isLogin: true);
    }
    if (dogecoinCore != null) {
      local['dogecoin'] = dogecoinCore?.localShare?.privateKey;
    }
    if (aptosCore == null) {
      await init(chain: SbtChain.APTOS, isLogin: true);
    }
    if (aptosCore != null) {
      local['aptos'] = aptosCore?.localShare?.privateKey;
    }
    final encrypted = await encryptMsg(jsonEncode(local), password);
    await api.confirmLoginWithQrCode(qrCodeId, encrypted);
  }

  /// Send verify Code
  Future<void> sendVerifyCode(
    String email, {
    String areaCode = '',
    String phoneNumber = '',
    LoginType loginType = LoginType.email,
  }) async {
    await SbtAuthApi.sendEmailCode(
      email: email,
      areaCode: areaCode,
      phoneNumber: phoneNumber,
      baseUrl: _baseUrl,
      clientID: _clientId,
      loginType: loginType,
    );
  }

  /// Init local share
  Future<void> recoverWithDevice(
    String code, {
    SbtChain chain = SbtChain.EVM,
  }) async {
    final eventSource =
        await EventSource.connect('$_baseUrl/sse:connect?access_token=$token');
    final completer = Completer<String>();
    eventSource.listen((Event event) {
      if (event.id != null) {
        api.confirmEventReceived(event.id!, 'AUTH_CONFIRM');
        completer.complete(event.data);
        eventSource.client.close();
      }
    });
    final data = await completer.future;
    final remoteShareInfo = await api.fetchRemoteShare(keyType: chain.name);
    final shareString = await decryptMsg(
      (jsonDecode(data) as Map)['encryptedFragment'].toString(),
      code,
    );
    final localShare = Share(
      privateKey: shareString,
      publicKey: remoteShareInfo.remote.publicKey,
      extraData: remoteShareInfo.localAux,
    );
    final core = getCore(chain);
    final hash = bytesToHex(
      hashMessage(ascii.encode(jsonEncode(localShare.toJson()))),
      include0x: true,
    );
    if (hash != remoteShareInfo.localHash) {
      throw SbtAuthException('Recover failed');
    }
    final inited = await core.init(
      address: remoteShareInfo.address,
      remote: remoteShareInfo.remote,
      local: localShare,
      isTestnet: developMode,
    );
    switch (chain) {
      case SbtChain.EVM:
        _core = core;
        break;
      case SbtChain.SOLANA:
        _solanaCore = core;
        break;
      case SbtChain.BITCOIN:
        _bitcoinCore = core;
        break;
      case SbtChain.DOGECOIN:
        _dogecoinCore = core;
        break;
      case SbtChain.APTOS:
        _aptosCore = core;
        break;
      case SbtChain.NEAR:
        _nearCore = core;
        break;
      case SbtChain.TRON:
        _tronCore = core;
        break;
    }
    if (!inited) throw SbtAuthException('Init error');
    await DBUtil.auxBox.put(
      core.getAddress(isTestnet: developMode),
      remoteShareInfo.backupAux,
    );
    await DBUtil.hashBox.put(
      core.getAddress(isTestnet: developMode),
      remoteShareInfo.backupHash,
    );
    await _authRequestListener();
    await api.verifyIdentity(localShare, keyType: chain.name);
  }

  /// Recover with privateKey
  Future<void> recoverWidthBackup(
    String backupPrivateKey,
    String password, {
    SbtChain chain = SbtChain.EVM,
  }) async {
    final remoteShareInfo = await api.fetchRemoteShare(keyType: chain.name);
    var backup = '';
    if (backupPrivateKey.startsWith('0x')) {
      backup = backupPrivateKey;
    } else {
      backup = await decryptMsg(backupPrivateKey, password);
    }
    final core = getCore(chain);
    final backShare = Share(
      privateKey: backup,
      publicKey: remoteShareInfo.remote.publicKey,
      extraData: remoteShareInfo.backupAux,
    );
    final hash = bytesToHex(
      hashMessage(ascii.encode(jsonEncode(backShare.toJson()))),
      include0x: true,
    );
    if (hash != remoteShareInfo.backupHash) {
      throw SbtAuthException('Recover failed');
    }
    final inited = await core.init(
      address: remoteShareInfo.address,
      remote: remoteShareInfo.remote,
      backup: backShare,
      localAux: remoteShareInfo.localAux,
      isTestnet: developMode,
    );
    switch (chain) {
      case SbtChain.EVM:
        _core = core;
        break;
      case SbtChain.SOLANA:
        _solanaCore = core;
        break;
      case SbtChain.BITCOIN:
        _bitcoinCore = core;
        break;
      case SbtChain.DOGECOIN:
        _dogecoinCore = core;
        break;
      case SbtChain.APTOS:
        _aptosCore = core;
        break;
      case SbtChain.NEAR:
        _nearCore = core;
        break;
      case SbtChain.TRON:
        _tronCore = core;
        break;
    }
    if (!inited) throw SbtAuthException('Init error');
    await DBUtil.auxBox.put(
      core.getAddress(isTestnet: developMode),
      remoteShareInfo.backupAux,
    );
    await DBUtil.hashBox.put(
      core.getAddress(isTestnet: developMode),
      remoteShareInfo.backupHash,
    );
    await _authRequestListener();
    await api.verifyIdentity(core.localShare!, keyType: chain.name);
  }

  /// One drive batch backup
  Future<void> oneDriveBatchBackup(
    String password, {
    String? customUrl,
    String googleCode = '',
  }) async {
    final baseUrl =
        customUrl ?? (developMode ? DEVELOP_AUTH_URL : PRODUCTION_AUTH_URL);
    final oneDriveUrl =
        '$baseUrl/onedrive?scheme=$_scheme&developMode=$developMode';
    unawaited(
      launchUrl(
        Uri.parse(oneDriveUrl),
        mode: Platform.isAndroid
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault,
      ),
    );
    final completer = Completer<String?>();
    final appLinks = AppLinks();
    final linkSubscription = appLinks.uriLinkStream.listen((uri) {
      if (uri.toString().startsWith(_scheme)) {
        completer.complete(jsonEncode(uri.queryParameters));
      }
    });
    final data = await completer.future;
    final dataMap = jsonDecode(data!) as Map<String, dynamic>;
    final code = dataMap['code'] as String;
    final state = dataMap['state'] as String;
    loadingStreamController.add(true);
    final backupInfo = await getBackupData(password);
    try {
      await api.oneDriveBatchBackup(
        code,
        state == 'undefined' ? 'state' : state,
        backupInfo,
        googleCode: googleCode,
      );
      if (Platform.isIOS) {
        await closeInAppWebView();
      }
      await linkSubscription.cancel();
    } catch (e) {
      rethrow;
    } finally {
      loadingStreamController.add(false);
    }
  }

  /// Recover by one drive
  Future<void> recoverByOneDrive(
    String password, {
    SbtChain chain = SbtChain.EVM,
    String? customUrl,
  }) async {
    final baseUrl =
        customUrl ?? (developMode ? DEVELOP_AUTH_URL : PRODUCTION_AUTH_URL);
    final oneDriveUrl =
        '$baseUrl/onedrive?scheme=$_scheme&developMode=$developMode';
    unawaited(
      launchUrl(
        Uri.parse(oneDriveUrl),
        mode: Platform.isAndroid
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault,
      ),
    );
    final completer = Completer<String?>();
    final appLinks = AppLinks();
    appLinks.uriLinkStream.listen((uri) {
      if (uri.toString().startsWith(_scheme)) {
        completer.complete(jsonEncode(uri.queryParameters));
      }
    });
    final data = await completer.future;
    final dataMap = jsonDecode(data!) as Map<String, dynamic>;
    final code = dataMap['code'] as String;
    final state = dataMap['state'] as String;
    loadingStreamController.add(true);
    try {
      final res = await api.recoverByOneDrive(
        code,
        state == 'undefined' ? 'state' : state,
        keyType: chain.name,
      );
      final dataList = jsonDecode(res) as List;
      if (Platform.isIOS) {
        await closeInAppWebView();
      }
      await batchRecover(password, dataList);
    } catch (e) {
      rethrow;
    } finally {
      loadingStreamController.add(false);
    }
  }

  /// Auth request listener
  Future<void> _authRequestListener() async {
    _eventSource =
        await EventSource.connect('$_baseUrl/sse:connect?access_token=$token');
    _eventSource!.listen((Event event) {
      if (event.event == 'AUTH_APPLY') {
        if (!authRequestStreamController.isClosed && event.id != null) {
          authRequestStreamController.add(event.data!);
          api.confirmEventReceived(event.id!, 'AUTH_APPLY');
        }
      }
    });
  }

  /// Switch white list
  Future<void> switchWhiteList(
    String code, {
    required bool whitelistSwitch,
    String googleCode = '',
  }) async {
    await api.switchUserWhiteList(
      user!.email,
      code,
      whitelistSwitch: whitelistSwitch,
      googleCode: googleCode,
    );
    await getUserInfo();
  }

  /// get user info
  Future<void> getUserInfo() async {
    _user = await api.getUserInfo();
    await DBUtil.userBox.put('user', user);
    if (core != null) {
      core!.signModel = user!.whitelistSwitch;
    }
    if (solanaCore != null) {
      solanaCore!.signModel = user!.whitelistSwitch;
    }
    if (bitcoinCore != null) {
      bitcoinCore!.signModel = user!.whitelistSwitch;
    }
    if (dogecoinCore != null) {
      dogecoinCore!.signModel = user!.whitelistSwitch;
    }
    if (aptosCore != null) {
      aptosCore!.signModel = user!.whitelistSwitch;
    }
  }

  /// Create white list
  Future<void> createWhiteList(
    String authCode,
    String address,
    String name,
    String network, {
    bool toLowerCase = true,
    String googleCode = '',
  }) async {
    await api.createUserWhiteList(
      user!.email,
      authCode,
      toLowerCase ? address.toLowerCase() : address,
      name,
      network,
      googleCode: googleCode,
    );
  }

  /// Delete white list
  Future<void> deleteWhiteList(
    String authCode,
    String userWhitelistID, {
    String googleCode = '',
  }) async {
    await api.deleteUserWhiteList(
      user!.email,
      authCode,
      userWhitelistID,
      googleCode: googleCode,
    );
  }

  /// Edit white list
  Future<void> editWhiteList(
    String authCode,
    String address,
    String name,
    String userWhitelistID,
    String userId,
    String network, {
    bool toLowerCase = true,
    String googleCode = '',
  }) async {
    await api.editUserWhiteList(
      user!.email,
      authCode,
      toLowerCase ? address.toLowerCase() : address,
      name,
      userWhitelistID,
      userId,
      network,
      googleCode: googleCode,
    );
  }

  String _getLocale(LocaleType localType) {
    switch (localType) {
      case LocaleType.en_US:
        return 'en-US';
      case LocaleType.zh_CN:
        return 'zh-CN';
      case LocaleType.zh_TW:
        return 'zh-TW';
    }
  }

  /// Batch recover
  Future<void> batchRecover(
    String password,
    List<dynamic> privateKeyList,
  ) async {
    for (var i = 0; i < privateKeyList.length; i++) {
      final chain =
          SbtChain.values.byName(privateKeyList[i]['network'] as String);
      final backupPrivateKey = privateKeyList[i]['privateKey'] as String;
      final remoteShareInfo = await api.fetchRemoteShare(keyType: chain.name);
      var backup = '';
      if (backupPrivateKey.startsWith('0x')) {
        backup = backupPrivateKey;
      } else {
        backup = await decryptMsg(backupPrivateKey, password);
      }
      final core = getCore(chain);
      final backShare = Share(
        privateKey: backup,
        publicKey: remoteShareInfo.remote.publicKey,
        extraData: remoteShareInfo.backupAux,
      );
      final hash = bytesToHex(
        hashMessage(ascii.encode(jsonEncode(backShare.toJson()))),
        include0x: true,
      );
      if (hash != remoteShareInfo.backupHash) {
        throw SbtAuthException('Recover failed');
      }
      final inited = await core.init(
        address: remoteShareInfo.address,
        remote: remoteShareInfo.remote,
        backup: backShare,
        localAux: remoteShareInfo.localAux,
        isTestnet: developMode,
      );
      switch (chain) {
        case SbtChain.EVM:
          _core = core;
          break;
        case SbtChain.SOLANA:
          _solanaCore = core;
          break;
        case SbtChain.BITCOIN:
          _bitcoinCore = core;
          break;
        case SbtChain.DOGECOIN:
          _dogecoinCore = core;
          break;
        case SbtChain.APTOS:
          _aptosCore = core;
          break;
        case SbtChain.NEAR:
          _nearCore = core;
          break;
        case SbtChain.TRON:
          _tronCore = core;
          break;
      }
      if (!inited) throw SbtAuthException('Init error');
      await DBUtil.auxBox.put(
        core.getAddress(isTestnet: developMode),
        remoteShareInfo.backupAux,
      );
      await DBUtil.hashBox.put(
        core.getAddress(isTestnet: developMode),
        remoteShareInfo.backupHash,
      );
      await api.verifyIdentity(core.localShare!, keyType: chain.name);
    }
    await _authRequestListener();
  }

  /// Get privateKey
  Future<String> getPrivateKey(
    String address,
    String backupPrivateKey,
    String password, {
    bool isTestnet = false,
    String chain = 'EVM',
  }) async {
    final local = DBUtil.shareBox!.get(address);
    if (local == null) throw SbtAuthException('$address non-existent');
    final aux = DBUtil.auxBox.get(address);
    if (aux == null) throw SbtAuthException('$address aux non-existent');
    var backup = '';
    if (backupPrivateKey.startsWith('0x')) {
      backup = backupPrivateKey;
    } else {
      backup = await decryptMsg(backupPrivateKey, password);
    }
    final backupHash = DBUtil.hashBox.get(address);
    final backShare = Share(
      privateKey: backup,
      publicKey: local.publicKey,
      extraData: aux,
    );
    final hash = bytesToHex(
      hashMessage(ascii.encode(jsonEncode(backShare.toJson()))),
      include0x: true,
    );
    if (hash != backupHash) {
      throw SbtAuthException('$address password error');
    }
    final privateKey = await MultiMpc.secretKey(
      [
        shareToKey(local),
        shareToKey(backShare, index: 3),
      ],
      SbtChain.values.byName(chain).engine,
    );
    return privateKey;
  }

  void _saveToken(String token) {
    DBUtil.tokenBox.put(TOKEN_KEY, token);
  }

  /// Get token list
  Future<List<TokenInfo>> getTokenList(
    int pageNo,
    int pageSize,
    String network,
    String condition,
  ) async {
    final res = await api.getTokenList(pageNo, pageSize, network, condition);
    return res.items;
  }

  /// Create strategy
  Future<void> createStrategy(
    List<Map<String, dynamic>> commandList, {
    String googleCode = '',
  }) async {
    await api.createStrategy(commandList, googleCode: googleCode);
  }

  /// Edit strategy
  Future<void> editStrategy(
    List<Map<String, dynamic>> commandList, {
    String googleCode = '',
  }) async {
    await api.editStrategy(commandList, googleCode: googleCode);
  }

  Future<void> _initCoreWithLocalPrivateKey(
    String privateKey,
    SbtChain chain,
  ) async {
    final remoteShareInfo = await api.fetchRemoteShare(keyType: chain.name);
    final localShare = Share(
      privateKey: privateKey,
      publicKey: remoteShareInfo.remote.publicKey,
      extraData: remoteShareInfo.localAux,
    );
    final core = AuthCore(
      mpcUrl: MpcUrl(
        url: _baseUrl,
        get: 'user/forward:query:data',
        set: 'user/forward:data',
      ),
      signUrl: '$_baseUrl/user:sign',
      token: token,
      chain: chain,
    );
    final inited = await core.init(
      address: remoteShareInfo.address,
      remote: remoteShareInfo.remote,
      local: localShare,
      isTestnet: developMode,
    );
    if (!inited) throw SbtAuthException('Init error');
    switch (chain) {
      case SbtChain.EVM:
        _core = core;
        break;
      case SbtChain.SOLANA:
        _solanaCore = core;
        break;
      case SbtChain.BITCOIN:
        _bitcoinCore = core;
        break;
      case SbtChain.DOGECOIN:
        _dogecoinCore = core;
        break;
      case SbtChain.APTOS:
        _aptosCore = core;
        break;
      case SbtChain.NEAR:
        _nearCore = core;
        break;
      case SbtChain.TRON:
        _tronCore = core;
        break;
    }
  }

  /// Request friend recover
  Future<String> requestFriendRecover() async {
    final eventSource =
        await EventSource.connect('$_baseUrl/sse:connect?access_token=$token');
    final completer = Completer<String>();
    eventSource.listen((Event event) {
      if (event.id != null) {
        api.confirmEventReceived(event.id!, 'SOCIAL_RECOVER');
        completer.complete(event.data);
        eventSource.client.close();
      }
    });
    final data = await completer.future;
    return data;
  }

  /// Get backup info
  Future<Map<String, dynamic>> getBackupData(String password) async {
    final backupInfo = <String, dynamic>{};
    if (_core == null) {
      await init(isLogin: true);
    }
    if (_solanaCore == null) {
      await init(isLogin: true, chain: SbtChain.SOLANA);
    }
    if (_bitcoinCore == null) {
      await init(isLogin: true, chain: SbtChain.BITCOIN);
    }
    if (_dogecoinCore == null) {
      await init(isLogin: true, chain: SbtChain.DOGECOIN);
    }
    if (_aptosCore == null) {
      await init(isLogin: true, chain: SbtChain.APTOS);
    }
    if (_tronCore == null) {
      await init(isLogin: true, chain: SbtChain.TRON);
    }
    final coreList = <AuthCore?>[
      _core,
      _solanaCore,
      _bitcoinCore,
      _dogecoinCore,
      _aptosCore,
      null,
      // _nearCore,
      _tronCore,
    ];
    for (var i = 0; i < SbtChain.values.length; i++) {
      if (coreList[i] != null) {
        final remoteShareInfo =
            await api.fetchRemoteShare(keyType: SbtChain.values[i].name);
        final backupPrivateKey =
            await coreList[i]!.getBackupPrivateKey(remoteShareInfo.backupAux);
        final privateKey = await encryptMsg(backupPrivateKey, password);
        backupInfo[SbtChain.values[i].name] = privateKey;
      }
    }
    return backupInfo;
  }

  /// Send friend share
  Future<void> sendFriendShare(String userId, String deviceName) async {
    final shareData = getFriendShare(userId) ?? '';
    await api.socialRecover(userId, deviceName, shareData);
  }

  /// Add backup friend
  Future<void> addBackupFriend(String userID) async {
    await api.addBackupFriend(userID, _clientId);
  }

  Stream<StreamResponse> _queryWhetherSuccess(
    String password,
    String qrcode,
    StreamController<StreamResponse> controller,
  ) {
    var counter = 0;
    const interval = Duration(seconds: 2);
    var result = QrCodeStatus(
      qrcodeName: '',
      qrcodeClientID: '',
      qrcodeExpireAt: '',
      fail: true,
      qrcodeEncryptedFragment: '',
    );

    Future<void> tick(_) async {
      counter++;
      debugPrint('trying $counter time');

      try {
        result = await SbtAuthApi.getQrCodeStatus(_baseUrl, qrcode);
      } catch (e) {
        _timer?.cancel();
      }
      if (result.qrcodeEncryptedFragment != '') {
        final token = result.qrcodeAuthToken!;
        _saveToken(token);
        await getUserInfo();
        final shareData = result.qrcodeEncryptedFragment!;
        final shareString = await decryptMsg(
          shareData,
          password,
        );
        final localShares = jsonDecode(shareString);
        final clientId = localShares['clientId'];
        if (clientId != _clientId) throw SbtAuthException('ClientId not match');
        if (localShares['evm'] != null) {
          await _initCoreWithLocalPrivateKey(
            localShares['evm']!.toString(),
            SbtChain.EVM,
          );
          await api.verifyIdentity(core!.localShare!);
        }
        if (localShares['solana'] != null) {
          await _initCoreWithLocalPrivateKey(
            localShares['solana']!.toString(),
            SbtChain.SOLANA,
          );
          await api.verifyIdentity(solanaCore!.localShare!, keyType: 'SOLANA');
        }
        if (localShares['dogecoin'] != null) {
          await _initCoreWithLocalPrivateKey(
            localShares['dogecoin']!.toString(),
            SbtChain.DOGECOIN,
          );
          await api.verifyIdentity(dogecoinCore!.localShare!,
              keyType: 'DOGECOIN');
        }
        if (localShares['bitcoin'] != null) {
          await _initCoreWithLocalPrivateKey(
            localShares['bitcoin']!.toString(),
            SbtChain.BITCOIN,
          );
          await api.verifyIdentity(bitcoinCore!.localShare!,
              keyType: 'BITCOIN');
        }
        if (localShares['aptos'] != null) {
          await _initCoreWithLocalPrivateKey(
            localShares['aptos']!.toString(),
            SbtChain.APTOS,
          );
          await api.verifyIdentity(aptosCore!.localShare!, keyType: 'APTOS');
        }
        if (localShares['tron'] != null) {
          await _initCoreWithLocalPrivateKey(
            localShares['tron']!.toString(),
            SbtChain.TRON,
          );
          await api.verifyIdentity(tronCore!.localShare!, keyType: 'TRON');
        }
        await _authRequestListener();
        loginStreamController.add(true);
      }

      if (result.qrcodeEncryptedFragment != '') {
        _timer?.cancel();
      }
    }

    void startTimer() {
      _timer?.cancel();
      _timer = Timer.periodic(interval, tick);
    }

    void stopTimer() {
      _timer?.cancel();
      _timer = null;
    }

    controller = StreamController<StreamResponse>(
      onListen: startTimer,
      onPause: stopTimer,
      onResume: startTimer,
      onCancel: stopTimer,
    );

    return controller.stream;
  }
}

/// Stream Response
class StreamResponse {
  /// Stream Response
  StreamResponse(this.time, this.data);

  /// time
  final int time;

  /// data
  final FutureOr<String?>? data;

  @override
  String toString() => 'StreamResponse(time: $time, data: $data)';
}
