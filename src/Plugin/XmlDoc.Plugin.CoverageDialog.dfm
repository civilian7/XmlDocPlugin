object CoverageDialog: TCoverageDialog
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Documentation Coverage Report'
  ClientHeight = 550
  ClientWidth = 684
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poMainFormCenter
  OnCreate = FormCreate
  TextHeight = 15
  object lblSource: TLabel
    Left = 16
    Top = 16
    Width = 42
    Height = 15
    Caption = 'Source:'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object lblPhase: TLabel
    Left = 16
    Top = 460
    Width = 3
    Height = 15
  end
  object rbProject: TRadioButton
    Left = 24
    Top = 38
    Width = 640
    Height = 17
    Caption = 'Current Project'
    Checked = True
    TabOrder = 0
    TabStop = True
  end
  object rbDirectory: TRadioButton
    Left = 24
    Top = 62
    Width = 80
    Height = 17
    Caption = 'Directory:'
    TabOrder = 1
  end
  object edtDirectory: TEdit
    Left = 110
    Top = 59
    Width = 510
    Height = 23
    TabOrder = 2
  end
  object btnBrowse: TButton
    Left = 626
    Top = 58
    Width = 30
    Height = 25
    Caption = '...'
    TabOrder = 3
    OnClick = btnBrowseClick
  end
  object pnlStats: TPanel
    Left = 16
    Top = 94
    Width = 652
    Height = 70
    BevelOuter = bvLowered
    TabOrder = 4
    object lblTotal: TLabel
      Left = 12
      Top = 8
      Width = 37
      Height = 15
      Caption = 'Total: -'
    end
    object lblDocumented: TLabel
      Left = 180
      Top = 8
      Width = 80
      Height = 15
      Caption = 'Documented: -'
    end
    object lblComplete: TLabel
      Left = 380
      Top = 8
      Width = 63
      Height = 15
      Caption = 'Complete: -'
    end
    object lblPercent: TLabel
      Left = 590
      Top = 30
      Width = 17
      Height = 15
      Caption = '0%'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object pbCoverage: TProgressBar
      Left = 12
      Top = 30
      Width = 570
      Height = 18
      TabOrder = 0
    end
  end
  object lvItems: TListView
    Left = 16
    Top = 172
    Width = 652
    Height = 280
    Columns = <
      item
        Caption = 'Element'
        Width = 300
      end
      item
        Caption = 'Kind'
        Width = 80
      end
      item
        Caption = 'Level'
        Width = 100
      end
      item
        Caption = 'Missing Tags'
        Width = 160
      end>
    GridLines = True
    ReadOnly = True
    RowSelect = True
    TabOrder = 5
    ViewStyle = vsReport
    OnDblClick = lvItemsDblClick
  end
  object pbProgress: TProgressBar
    Left = 16
    Top = 478
    Width = 652
    Height = 16
    TabOrder = 6
  end
  object btnAnalyze: TButton
    Left = 396
    Top = 506
    Width = 90
    Height = 28
    Caption = 'Analyze'
    Default = True
    TabOrder = 7
    OnClick = btnAnalyzeClick
  end
  object btnExportHTML: TButton
    Left = 492
    Top = 506
    Width = 90
    Height = 28
    Caption = 'Export HTML'
    Enabled = False
    TabOrder = 8
    OnClick = btnExportHTMLClick
  end
  object btnClose: TButton
    Left = 588
    Top = 506
    Width = 80
    Height = 28
    Cancel = True
    Caption = 'Close'
    TabOrder = 9
    OnClick = btnCloseClick
  end
end
