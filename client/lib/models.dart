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

  WikiSearch({this.ArticleId});

  WikiSearch.fromJson(Map<String, dynamic> json) {
    ArticleId = json['article_id'];
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
