import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'models.dart';

class ApiPlaylist {
  String apiUrl = "https://dustingibson.com/api3/";
  //String apiUrl = "http://localhost:3032/";

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

  Future<WikiResults?> setPlaysetProgress(
      String username, int playsetPlaylistId) {
    return http
        .post(Uri.parse(
            "${apiUrl}playsetUsersProgress?username=${username}&playsetPlaylistId=${playsetPlaylistId}"))
        .then((onValue) {
      return WikiResults.fromJson(json.decode(onValue.body.trim()));
    });
  }

  Future<WikiResults?> setUserPlayset(String username, String playsetId) {
    return http
        .post(Uri.parse(
            "${apiUrl}userPlayset?username=${username}&playsetId=${playsetId}"))
        .then((onValue) {
      return WikiResults.fromJson(json.decode(onValue.body.trim()));
    });
  }

  Future<WikiResults?> removeUserPlayset(String id) {
    return http
        .delete(Uri.parse("${apiUrl}userPlayset?id=${id}"))
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

  Future<List<WikiPlaysetSearch>> getPlaysetSearch(String keyword) {
    return http
        .get(Uri.parse('${apiUrl}searchPlayset?keyword=${keyword}'))
        .then((onValue) {
      String body = onValue.body;
      Iterable d = json.decode(body.trim());
      return List<WikiPlaysetSearch>.from(
          d.map((x) => WikiPlaysetSearch.fromJson(x)));
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

  Future<List<WikiUserPlayset>> getUserPlaysets(String username) {
    return http
        .get(Uri.parse("${apiUrl}userPlayset?username=${username}"))
        .then((onValue) {
      String body = onValue.body;
      Iterable d = json.decode(body.trim());
      return List<WikiUserPlayset>.from(
          d.map((x) => WikiUserPlayset.fromJson(x)));
    });
  }

  Future<WikiPlaysetPlaylist> getNextInPlaylist(int id, String username) {
    return http
        .get(Uri.parse(
            "${apiUrl}nextPlaysetPlaylist?id=${id}&username=${username}"))
        .then((onValue) {
      return WikiPlaysetPlaylist.fromJson(json.decode(onValue.body.trim()));
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

  Future<WikiPlaysetDetails?> getPlaysetDetails(String id, String username) {
    return http
        .get(Uri.parse("${apiUrl}playset?id=${id}&username=${username}"))
        .then((onValue) {
      return WikiPlaysetDetails.fromJson(json.decode(onValue.body.trim()));
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
