enum DataSource { ft50, cepm }

extension DataSourceExt on DataSource {
  String get label {
    switch (this) {
      case DataSource.ft50:
        return 'FT50/UTD24';
      case DataSource.cepm:
        return 'CE/PM';
    }
  }

  String get subtitle {
    switch (this) {
      case DataSource.ft50:
        return 'FT50 / UTD24 Journal Scanner';
      case DataSource.cepm:
        return 'CE / PM Journal Scanner';
    }
  }

  String get papersFile {
    switch (this) {
      case DataSource.ft50:
        return 'data/papers.json';
      case DataSource.cepm:
        return 'data/cepm_papers.json';
    }
  }

  String get latestFile {
    switch (this) {
      case DataSource.ft50:
        return 'data/latest.json';
      case DataSource.cepm:
        return 'data/cepm_latest.json';
    }
  }

  String get stateKey {
    return name; // 'ft50' or 'cepm'
  }

  bool get hasTiers => this == DataSource.ft50;
}
