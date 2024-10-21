import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'models.dart';

class ApiPlaylist {
  String apiUrl = "https://dustingibson.com/api3/";

  Future<WikiResults?> setOverallProgress(
      String username, String sectionId, String status) {
    return http
        .put(Uri.parse(
            "${apiUrl}overallProgress?username=${username}&sectionId=${sectionId}&status=${status}"))
        .then((onValue) {
      return WikiResults.fromJson(json.decode(onValue.body.trim()));
    });
  }

  Future<WikiResults?> setAudioProgress(
      String username, String sectionId, int progress) {
    return http
        .put(Uri.parse(
            "${apiUrl}audioProgress?username=${username}&sectionId=${sectionId}&progress=${progress}"))
        .then((onValue) {
      return WikiResults.fromJson(json.decode(onValue.body.trim()));
    });
  }

  Future<WikiSearch> getSearch(String username, String article) {
    return http
        .get(Uri.parse(
            '${apiUrl}search?username=${username}&article=${article}'))
        .then((onValue) {
      return WikiSearch.fromJson(json.decode(onValue.body.trim()));
    });
  }

  Future<List<WikiArticle>> getArticle(String username, String wikiId) {
    return http
        .get(
            Uri.parse('${apiUrl}article?username=${username}&wikiId=${wikiId}'))
        .then((onValue) {
      String body = onValue.body;
      Iterable d = json.decode(body.trim());
      return List<WikiArticle>.from(d.map((x) => WikiArticle.fromJson(x)));
    });
  }

  Future<List<WikiRecent>> getRecent(String username) {
    return http
        .get(Uri.parse('${apiUrl}recent?username=${username}'))
        .then((onValue) {
      String body = onValue.body;
      Iterable d = json.decode(body.trim());
      return List<WikiRecent>.from(d.map((x) => WikiRecent.fromJson(x)));
    });
  }

  Future<WikiUser?> getUser(String username) {
    return http
        .get(Uri.parse("${apiUrl}user?username=${username}"))
        .then((onValue) {
      return WikiUser.fromJson(json.decode(onValue.body.trim()));
    });
  }

  AudioSource getAudioUrl(String id) {
    return AudioSource.uri(Uri.parse("${apiUrl}audio?id=${id}"));
  }
}
