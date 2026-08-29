import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// MiMo Claw SSO 登录服务
///
/// 处理小米账号 SSO 登录流程：
/// 1. 获取登录页面 URL
/// 2. 用户在 WebView 中完成登录
/// 3. 从 Cookie 中提取 ph 值
/// 4. 使用 ph 获取 WS ticket
class MiMoClawAuth {
  static const String _baseUrl = 'https://aistudio.xiaomimimo.com';
  static const String _loginUrl =
      'https://account.xiaomi.com/fe/service/login/password';

  final Dio _dio;

  MiMoClawAuth({Dio? dio}) : _dio = dio ?? Dio();

  /// 获取登录 URL（用于 WebView 加载）
  String getLoginUrl() {
    return '$_loginUrl?followup=$_baseUrl/sts&service=miclaw&_json=true';
  }

  /// 从 Cookie 字符串中提取 ph 值
  String? extractPhFromCookies(String cookies) {
    return cookies
        .split(';')
        .map((c) => c.trim())
        .where((c) => c.startsWith('xiaomichatbot_ph='))
        .map((c) => c.substring('xiaomichatbot_ph='.length).replaceAll('"', ''))
        .firstOrNull;
  }

  /// 验证 Cookie 是否有效
  Future<bool> validateCookies(String cookies) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/open-apis/user/mi/get',
        options: Options(
          headers: {
            'Cookie': cookies,
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14) Chrome/137.0.0.0 Mobile Safari/537.36',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          return data['code'] == 0 && data['data'] != null;
        }
      }
      return false;
    } catch (e) {
      debugPrint('MiMoClawAuth 验证失败: $e');
      return false;
    }
  }

  /// 获取用户信息
  Future<Map<String, dynamic>?> getUserInfo(String cookies) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/open-apis/user/mi/get',
        options: Options(
          headers: {
            'Cookie': cookies,
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14) Chrome/137.0.0.0 Mobile Safari/537.36',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['code'] == 0) {
          return data['data'] as Map<String, dynamic>?;
        }
      }
      return null;
    } catch (e) {
      debugPrint('MiMoClawAuth 获取用户信息失败: $e');
      return null;
    }
  }

  /// 获取 WS ticket
  Future<String?> getWsTicket(String cookies) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/open-apis/user/ws/ticket',
        options: Options(
          headers: {
            'Cookie': cookies,
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14) Chrome/137.0.0.0 Mobile Safari/537.36',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          final ticket = data['data']?['ticket'] ?? data['ticket'];
          if (ticket != null && ticket.toString().isNotEmpty) {
            return ticket.toString();
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('MiMoClawAuth 获取 ticket 失败: $e');
      return null;
    }
  }

  /// 获取 Bot 配置
  Future<Map<String, dynamic>?> getBotConfig(String cookies) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/open-apis/bot/config',
        options: Options(
          headers: {
            'Cookie': cookies,
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14) Chrome/137.0.0.0 Mobile Safari/537.36',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['code'] == 0) {
          return data['data'] as Map<String, dynamic>?;
        }
      }
      return null;
    } catch (e) {
      debugPrint('MiMoClawAuth 获取 Bot 配置失败: $e');
      return null;
    }
  }
}
