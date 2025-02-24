class WikiUser {
  int? Id;
  String? Username;
  String? Provider;

  WikiUser({this.Id, this.Username, this.Provider});

  WikiUser.fromJson(Map<String, dynamic> json) {
    Id = json['id'];
    Username = json['username'];
    Provider = json['provider'];
  }
}

class WikiArticle {
  String? ArticleId;
  String? SectionId;
  String? ArticleTitle;
  String? SectionTitle;
  int? AudioProgress;
  String? Url;
  int? Version;
  String? Status;
  bool IsPlaying = false;

  WikiArticle(
      {this.ArticleId,
      this.SectionId,
      this.ArticleTitle,
      this.SectionTitle,
      this.AudioProgress,
      this.Url,
      this.Status,
      this.Version});

  WikiArticle.fromJson(Map<String, dynamic> json) {
    ArticleId = json['article_id'];
    SectionId = json['section_id'];
    ArticleTitle = json['article_title'];
    SectionTitle = json['section_title'];
    AudioProgress = json['audio_progress'];
    Url = json['url'];
    Status = json['status'];
    Version = json['verison'];
  }
}

class WikiRecent {
  String? ArticleId;
  String? ArticleTitle;
  int? Version;

  WikiRecent({this.ArticleId, this.ArticleTitle, this.Version});

  WikiRecent.fromJson(Map<String, dynamic> json) {
    ArticleId = json['article_id'];
    ArticleTitle = json['article_title'];
    Version = json['version'];
  }
}

class WikiSearch {
  String? ArticleId;
  String? ArticleTitle;

  WikiSearch({this.ArticleId, this.ArticleTitle});

  WikiSearch.fromJson(Map<String, dynamic> json) {
    ArticleId = json['article_id'];
    ArticleTitle = json['article_title'];
  }
}

class WikiResults {
  int? Status;
  String? Message;

  WikiResults({this.Status, this.Message});

  WikiResults.fromJson(Map<String, dynamic> json) {
    Status = json['status'];
    Message = json['message'];
  }
}

class WikiPlaysetPlaylist {
  int? Id;
  String? PlaysetId;
  String? ArticleId;
  String? ArticleTitle;

  WikiPlaysetPlaylist(
      {this.Id, this.PlaysetId, this.ArticleId, this.ArticleTitle});

  WikiPlaysetPlaylist.fromJson(Map<String, dynamic> json) {
    Id = json['id'];
    PlaysetId = json['playsetId'];
    ArticleId = json['wikipediaArticle']['id'];
    ArticleTitle = json['wikipediaArticle']['title'];
  }
}

class WikiPlaysetDetails {
  String? Id;
  String? Name;
  List<WikiPlaysetPlaylist>? PlaysetPlaylist;
  int? CurrentPlaysetPlaylistId;

  WikiPlaysetDetails(
      {this.Id,
      this.Name,
      this.PlaysetPlaylist,
      this.CurrentPlaysetPlaylistId});

  WikiPlaysetDetails.fromJson(Map<String, dynamic> json) {
    CurrentPlaysetPlaylistId = json['currentPlaysetPlaylistId'];
    Id = json['id'];
    Name = json['name'];
    PlaysetPlaylist = List<WikiPlaysetPlaylist>.from(
        (json['playlist'] as List).map((x) => WikiPlaysetPlaylist.fromJson(x)));
  }
}

class WikiPlaysetSearch {
  String? Id;
  String? Name;

  WikiPlaysetSearch({this.Id, this.Name});

  WikiPlaysetSearch.fromJson(Map<String, dynamic> json) {
    Id = json['id'];
    Name = json['name'];
  }
}

class WikiUserPlayset {
  int? UsersPlaysetId;
  String? PlaysetId;
  String? Name;

  WikiUserPlayset({this.UsersPlaysetId, this.PlaysetId, this.Name});

  WikiUserPlayset.fromJson(Map<String, dynamic> json) {
    UsersPlaysetId = json['usersPlaysetId'];
    PlaysetId = json['playsetId'];
    Name = json['name'];
  }
}
