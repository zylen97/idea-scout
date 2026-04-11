enum DataSource { cnki, ft50, cepm }

extension DataSourceExt on DataSource {
  String get label {
    switch (this) {
      case DataSource.ft50:
        return 'FT50/UTD24';
      case DataSource.cepm:
        return 'CE/PM';
      case DataSource.cnki:
        return 'CNKI';
    }
  }

  String get subtitle {
    switch (this) {
      case DataSource.ft50:
        return 'FT50 / UTD24 Journal Scanner';
      case DataSource.cepm:
        return 'CE / PM Journal Scanner';
      case DataSource.cnki:
        return 'CNKI Chinese Journal Scanner';
    }
  }

  String get papersFile {
    switch (this) {
      case DataSource.ft50:
        return 'data/papers.json';
      case DataSource.cepm:
        return 'data/cepm_papers.json';
      case DataSource.cnki:
        return 'data/cnki_papers.json';
    }
  }

  String get latestFile {
    switch (this) {
      case DataSource.ft50:
        return 'data/latest.json';
      case DataSource.cepm:
        return 'data/cepm_latest.json';
      case DataSource.cnki:
        return 'data/cnki_latest.json';
    }
  }

  String get stateKey {
    return name; // 'ft50', 'cepm', or 'cnki'
  }

  bool get hasTiers => this == DataSource.ft50 || this == DataSource.cnki;

  bool get isCnki => this == DataSource.cnki;
}
