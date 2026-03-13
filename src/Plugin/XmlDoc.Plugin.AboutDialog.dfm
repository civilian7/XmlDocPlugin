object AboutDialog: TAboutDialog
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'About XmlDoc Plugin'
  ClientHeight = 469
  ClientWidth = 500
  Color = clWhite
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poMainFormCenter
  OnCreate = FormCreate
  TextHeight = 15
  object pnlBottom: TPanel
    Left = 0
    Top = 429
    Width = 500
    Height = 40
    Align = alBottom
    BevelOuter = bvNone
    ParentBackground = False
    TabOrder = 0
    ExplicitTop = 390
    object btnOK: TButton
      Left = 210
      Top = 6
      Width = 80
      Height = 28
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
  end
  object scrlContent: TScrollBox
    Left = 0
    Top = 0
    Width = 500
    Height = 429
    Align = alClient
    BorderStyle = bsNone
    Color = clWhite
    ParentColor = False
    TabOrder = 1
    ExplicitHeight = 390
    object lblTitle: TLabel
      Left = 24
      Top = 24
      Width = 452
      Height = 23
      AutoSize = False
      Caption = 'XmlDoc Plugin'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -17
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object lblVersion: TLabel
      Left = 24
      Top = 50
      Width = 452
      Height = 15
      AutoSize = False
      Caption = 'Version 0.5.0'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGray
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object lblDescription: TLabel
      Left = 24
      Top = 76
      Width = 452
      Height = 48
      AutoSize = False
      Caption = 
        'A Delphi IDE plugin for editing and managing XML documentation c' +
        'omments. Provides a WYSIWYG editor, documentation stub generatio' +
        'n, help file generation, and coverage reporting.'
      WordWrap = True
    end
    object lblCopyright: TLabel
      Left = 24
      Top = 132
      Width = 452
      Height = 15
      AutoSize = False
      Caption = #169' Copyright 2026, by Fullbit Computing'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGrayText
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object bvlSeparator: TBevel
      Left = 24
      Top = 178
      Width = 452
      Height = 2
      Shape = bsTopLine
    end
    object lblOSSHeader: TLabel
      Left = 24
      Top = 190
      Width = 452
      Height = 15
      AutoSize = False
      Caption = 'Open Source Libraries'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = cl3DDkShadow
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object lblLib1Name: TLabel
      Left = 24
      Top = 216
      Width = 452
      Height = 15
      AutoSize = False
      Caption = 'DelphiAST '#8212' Mozilla Public License 2.0'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object lblLib2Name: TLabel
      Left = 24
      Top = 258
      Width = 452
      Height = 15
      AutoSize = False
      Caption = 'TipTap Editor '#8212' MIT License'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object lblLib3Name: TLabel
      Left = 24
      Top = 300
      Width = 452
      Height = 15
      AutoSize = False
      Caption = 'ProseMirror '#8212' MIT License'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object lblLib4Name: TLabel
      Left = 24
      Top = 342
      Width = 452
      Height = 15
      AutoSize = False
      Caption = 'Vite '#8212' MIT License'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object lblLib5Name: TLabel
      Left = 24
      Top = 384
      Width = 452
      Height = 15
      AutoSize = False
      Caption = 'vite-plugin-singlefile '#8212' MIT License'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object lnkContact: TLinkLabel
      Left = 24
      Top = 150
      Width = 452
      Height = 17
      AutoSize = False
      Caption = '<a href="mailto:civilian7@gmail.com">civilian7@gmail.com</a>'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGrayText
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabOrder = 0
      OnLinkClick = OnLinkClick
    end
    object lnkLib1: TLinkLabel
      Left = 24
      Top = 233
      Width = 452
      Height = 17
      AutoSize = False
      Caption = 
        '<a href="https://github.com/RomanYankovsky/DelphiAST">github.com' +
        '/RomanYankovsky/DelphiAST</a>'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabOrder = 1
      OnLinkClick = OnLinkClick
    end
    object lnkLib2: TLinkLabel
      Left = 24
      Top = 275
      Width = 452
      Height = 17
      AutoSize = False
      Caption = '<a href="https://tiptap.dev">tiptap.dev</a>'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabOrder = 2
      OnLinkClick = OnLinkClick
    end
    object lnkLib3: TLinkLabel
      Left = 24
      Top = 317
      Width = 452
      Height = 17
      AutoSize = False
      Caption = '<a href="https://prosemirror.net">prosemirror.net</a>'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabOrder = 3
      OnLinkClick = OnLinkClick
    end
    object lnkLib4: TLinkLabel
      Left = 24
      Top = 359
      Width = 452
      Height = 17
      AutoSize = False
      Caption = '<a href="https://vite.dev">vite.dev</a>'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabOrder = 4
      OnLinkClick = OnLinkClick
    end
    object lnkLib5: TLinkLabel
      Left = 24
      Top = 401
      Width = 452
      Height = 17
      AutoSize = False
      Caption = 
        '<a href="https://github.com/nicola-trezzini/vite-plugin-singlefi' +
        'le">github.com/nicola-trezzini/vite-plugin-singlefile</a>'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabOrder = 5
      OnLinkClick = OnLinkClick
    end
  end
end
