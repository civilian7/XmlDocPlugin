object SettingsDialog: TSettingsDialog
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'XmlDoc Plugin Settings'
  ClientHeight = 410
  ClientWidth = 464
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poMainFormCenter
  OnCreate = FormCreate
  TextHeight = 15
  object PageControl: TPageControl
    Left = 0
    Top = 0
    Width = 464
    Height = 365
    ActivePage = tsGeneral
    Align = alTop
    TabOrder = 0
    object tsGeneral: TTabSheet
      Caption = 'General'
      object lblTheme: TLabel
        Left = 16
        Top = 16
        Width = 40
        Height = 15
        Caption = 'Theme:'
      end
      object lblFontSize: TLabel
        Left = 16
        Top = 48
        Width = 50
        Height = 15
        Caption = 'Font Size:'
      end
      object lblLanguage: TLabel
        Left = 16
        Top = 80
        Width = 55
        Height = 15
        Caption = 'Language:'
      end
      object cmbTheme: TComboBox
        Left = 130
        Top = 14
        Width = 160
        Height = 23
        Style = csDropDownList
        ItemIndex = 0
        TabOrder = 0
        Text = 'light'
        Items.Strings = (
          'light'
          'dark'
          'auto')
      end
      object spnFontSize: TSpinEdit
        Left = 130
        Top = 46
        Width = 80
        Height = 24
        MaxValue = 32
        MinValue = 8
        TabOrder = 1
        Value = 13
      end
      object cmbLanguage: TComboBox
        Left = 130
        Top = 78
        Width = 160
        Height = 23
        Style = csDropDownList
        ItemIndex = 0
        TabOrder = 2
        Text = 'auto'
        Items.Strings = (
          'auto'
          'en'
          'ko'
          'ja')
      end
      object chkAutoShowOnCursor: TCheckBox
        Left = 16
        Top = 118
        Width = 300
        Height = 17
        Caption = 'Auto show inspector on cursor move'
        TabOrder = 3
      end
      object chkCollapseEmptySections: TCheckBox
        Left = 16
        Top = 144
        Width = 300
        Height = 17
        Caption = 'Collapse empty sections'
        TabOrder = 4
      end
      object chkShowSignatureHeader: TCheckBox
        Left = 16
        Top = 170
        Width = 300
        Height = 17
        Caption = 'Show signature header'
        TabOrder = 5
      end
      object chkCheckUpdates: TCheckBox
        Left = 16
        Top = 196
        Width = 300
        Height = 17
        Caption = 'Check for updates on startup'
        TabOrder = 6
      end
    end
    object tsCodeGen: TTabSheet
      Caption = 'Code Generation'
      ImageIndex = 1
      object lblIndentStyle: TLabel
        Left = 16
        Top = 16
        Width = 65
        Height = 15
        Caption = 'Indent Style:'
      end
      object lblIndentSize: TLabel
        Left = 16
        Top = 48
        Width = 60
        Height = 15
        Caption = 'Indent Size:'
      end
      object lblPlaceholderPrefix: TLabel
        Left = 16
        Top = 264
        Width = 97
        Height = 15
        Caption = 'Placeholder Prefix:'
      end
      object cmbIndentStyle: TComboBox
        Left = 130
        Top = 14
        Width = 120
        Height = 23
        Style = csDropDownList
        ItemIndex = 0
        TabOrder = 0
        Text = 'Spaces'
        Items.Strings = (
          'Spaces'
          'Tabs')
      end
      object spnIndentSize: TSpinEdit
        Left = 130
        Top = 46
        Width = 80
        Height = 24
        MaxValue = 8
        MinValue = 1
        TabOrder = 1
        Value = 2
      end
      object chkBlankLineBefore: TCheckBox
        Left = 16
        Top = 88
        Width = 300
        Height = 17
        Caption = 'Blank line before XML doc comment'
        TabOrder = 2
      end
      object chkBlankLineAfter: TCheckBox
        Left = 16
        Top = 114
        Width = 300
        Height = 17
        Caption = 'Blank line after XML doc comment'
        TabOrder = 3
      end
      object chkOmitEmptyTags: TCheckBox
        Left = 16
        Top = 140
        Width = 300
        Height = 17
        Caption = 'Omit empty tags'
        TabOrder = 4
      end
      object chkAutoGenerate: TCheckBox
        Left = 16
        Top = 178
        Width = 300
        Height = 17
        Caption = 'Auto-generate stub on new declaration'
        TabOrder = 5
      end
      object edtPlaceholderPrefix: TEdit
        Left = 130
        Top = 262
        Width = 200
        Height = 23
        TabOrder = 6
      end
    end
    object tsShortcuts: TTabSheet
      Caption = 'Shortcuts'
      ImageIndex = 2
      object lblToggleInspector: TLabel
        Left = 16
        Top = 16
        Width = 91
        Height = 15
        Caption = 'Toggle Inspector:'
      end
      object lblGenerateStub: TLabel
        Left = 16
        Top = 52
        Width = 77
        Height = 15
        Caption = 'Generate Stub:'
      end
      object lblGenerateHelp: TLabel
        Left = 16
        Top = 88
        Width = 78
        Height = 15
        Caption = 'Generate Help:'
      end
      object lblCoverageReport: TLabel
        Left = 16
        Top = 124
        Width = 91
        Height = 15
        Caption = 'Coverage Report:'
      end
      object lblNextUndocumented: TLabel
        Left = 16
        Top = 160
        Width = 113
        Height = 15
        Caption = 'Next Undocumented:'
      end
      object lblPreviousUndocumented: TLabel
        Left = 16
        Top = 196
        Width = 134
        Height = 15
        Caption = 'Previous Undocumented:'
      end
      object hotToggleInspector: THotKey
        Left = 170
        Top = 14
        Width = 240
        Height = 23
        HotKey = 32833
        TabOrder = 0
      end
      object hotGenerateStub: THotKey
        Left = 170
        Top = 50
        Width = 240
        Height = 23
        HotKey = 32833
        TabOrder = 1
      end
      object hotGenerateHelp: THotKey
        Left = 170
        Top = 86
        Width = 240
        Height = 23
        HotKey = 32833
        TabOrder = 2
      end
      object hotCoverageReport: THotKey
        Left = 170
        Top = 122
        Width = 240
        Height = 23
        HotKey = 32833
        TabOrder = 3
      end
      object hotNextUndocumented: THotKey
        Left = 170
        Top = 158
        Width = 240
        Height = 23
        HotKey = 32833
        TabOrder = 4
      end
      object hotPreviousUndocumented: THotKey
        Left = 170
        Top = 194
        Width = 240
        Height = 23
        HotKey = 32833
        TabOrder = 5
      end
    end
    object tsAdvanced: TTabSheet
      Caption = 'Advanced'
      ImageIndex = 3
      object lblDebounceMs: TLabel
        Left = 16
        Top = 16
        Width = 84
        Height = 15
        Caption = 'Debounce (ms):'
      end
      object lblSaveDebounceMs: TLabel
        Left = 16
        Top = 52
        Width = 111
        Height = 15
        Caption = 'Save Debounce (ms):'
      end
      object lblLogLevel: TLabel
        Left = 16
        Top = 88
        Width = 53
        Height = 15
        Caption = 'Log Level:'
      end
      object spnDebounceMs: TSpinEdit
        Left = 150
        Top = 14
        Width = 100
        Height = 24
        Increment = 50
        MaxValue = 5000
        MinValue = 50
        TabOrder = 0
        Value = 300
      end
      object spnSaveDebounceMs: TSpinEdit
        Left = 150
        Top = 50
        Width = 100
        Height = 24
        Increment = 100
        MaxValue = 10000
        MinValue = 100
        TabOrder = 1
        Value = 500
      end
      object cmbLogLevel: TComboBox
        Left = 150
        Top = 86
        Width = 120
        Height = 23
        Style = csDropDownList
        ItemIndex = 1
        TabOrder = 2
        Text = 'Info'
        Items.Strings = (
          'Debug'
          'Info'
          'Warn'
          'Error'
          'Fatal')
      end
    end
  end
  object btnOK: TButton
    Left = 296
    Top = 375
    Width = 80
    Height = 28
    Caption = 'OK'
    Default = True
    ModalResult = 1
    TabOrder = 1
    OnClick = btnOKClick
  end
  object btnCancel: TButton
    Left = 382
    Top = 375
    Width = 80
    Height = 28
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 2
  end
end
