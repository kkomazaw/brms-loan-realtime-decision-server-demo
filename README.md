# JBoss BRMS 6.2： 住宅ローン審査による簡易ハンズオン

## はじめに
この資料では、住宅ローンの審査ロジックを題材としてJBoss BRMSによる実装手順をハンズオン形式で説明します。

## 前提条件
このハンズオンでは、インストールや事前の設定を巻末の補足資料に従って準備されていることが前提となります。必要な環境は以下のとおりです。
- JBoss BRMSサーバー用PC：１台
  - JDK 1.7以上がインストールされたOS (Oracle JDK, OpenJDK, IBM JDK)（Windows, LinuxまたはMacOS）
  - CPU 2コア以上、メモリ4GB以上、ディスク4GB以上の空き
  - Apache Maven 3.3+がインストールされていること
  - ポート8080がハンズオン用PCに公開されていること
- ハンズオン用PC：各受講者数
  - Firefoxブラウザ
  - RESTClientプラグイン(Firefox用)
  - JBoss BRMSサーバー用PCとネットワーク接続できること

## ハンズオンの進め方
このハンズオンでは、以下の手順でビジネスルールを作成します。
1. 承認ロジックの文書化
1. データモデルとビジネスルールの抽出
1. データモデルの作成
1. ビジネスルールの作成
1. ビジネスルールのテスト
1. ビジネスルールのデプロイ
1. ビジネスルールの呼出
1. ビジネスルールの変更

## ハンズオン手順
1. 承認ロジックの文書化
住宅ローンの借入を希望する<u>申請者</u>が、<u>住宅ローン申請</u>を行った場合、承認する審査基準は以下のとおりとする。
  1. _<u>申請者</u>_の_<u>年収</u>_、_<u>借入希望額</u>_、_<u>返済期間</u>_から算定される_<u>借入限度額</u>_が、借入希望額以上の場合、住宅ローン申請を_<u>承認</u>_する。
  1. _<u>借入限度額</u>_は以下の式で計算される。（元利均等返済の場合）
    - 借入限度額＝（年収 × 返済負担率）×（（１＋ 審査金利）^（返済期間 –１））÷（審査金利 ×（１＋審査金利）^（返済期間）））
  1. _<u>審査金利</u>_は_<u>ローン開始日</u>_の金利を適用する。（現時点の審査金利は4％（=0.04）とする。）
  1. _<u>返済負担率</u>_は以下の表に応じて決定される。

|年収条件             |返済負担率|
|:-------------------|:-------|
|250万円未満          |25％     |
|250万円以上400万円未満|30%      |
|400万円以上          |35％     |


## データモデルとビジネスルールの抽出
  1. 上記の文書から、ビジネスルールで扱うデータモデルを以下のように抽出します。（<u>下線</u>をデータモデル名、_<u>下線＋イタリック</u>_を属性にします。）

    - データモデル１：<u>申請者</u>
      - _<u>申請者</u>_：文字列
      - _<u>年収</u>_：整数値
    - データモデル２：<u>住宅ローン申請</u>
      - _<u>借入希望額</u>_：整数値
      -	_<u>ローン開始日</u>_：日付
      -	_<u>返済期間</u>_：整数値
      -	_<u>審査金利</u>_：実数値（小数点２桁）
      -	_<u>返済負担率</u>_：実数値（小数点２桁）
      -	_<u>借入限度額</u>_：実数値（小数点２桁）
      -	_<u>承認可否</u>_：真偽値

  1.	次にビジネスルールの抽出を行います。まずは実装の制約を考慮せずに検討します。

    - ビジネスルール１：[承認可否の判定]

          「<u>住宅ローン申請</u>の_<u>借入限度額</u>_が_<u>借入希望額</u>_以上の場合、<u>住宅ローン申請</u>を_<u>承認</u>_する。」

    - ビジネスルール２：[借入限度額の計算]

          「<u>住宅ローン申請</u>の_<u>借入限度額</u>_は、（_<u>年収</u>_ × _<u>返済負担率</u>_）×（（１＋ _<u>審査金利</u>_）^（_<u>返済期間</u>_ –１））÷（_<u>審査金利</u>_ ×（１＋_<u>審査金利</u>_）^（_<u>返済期間</u>_））として計算する。」

    - ビジネスルール３：[審査金利の設定]

          「<u>住宅ローン申請</u>の_<u>審査金利</u>_は4%とする。」（今回は簡略化のためローン開始日を考慮しません）

    - ビジネスルール４：[返済負担率の決定]

          「<u>住宅ローン申請</u>の_<u>返済負担率</u>_は、以下の表で決定する。」

|年収条件|返済負担率|
|:--|:--|
|250万円未満|25％|
|250万円以上400万円未満|30%|
|400万円以上|35％|

  1. それぞれのビジネスルールには依存関係がありますので、関係性を整理します。

    1. ビジネスルール３：[審査金利の設定]により_<u>審査金利</u>_が設定される。
    1. ビジネスルール４：[返済負担率の決定]により_<u>返済負担率</u>_が設定される。（実際は１と２はどちらが先行して設定されても良い）
    1. _<u>審査金利</u>_と_<u>返済負担率</u>_が設定された場合、ビジネスルール２：[借入限度額の計算]により_<u>借入限度額</u>_が設定される。
    1. _<u>借入限度額</u>_が設定された場合、ビジネスルール１：[承認可否の判定]により_<u>承認可否</u>_が設定される。

  1. この関係性を保ちながら実行されるように、BRMSの実装を考慮したビジネスルールに書き換えます。

    - ビジネスルール１’：[承認可否の判定]

      （条件部）
      <u>住宅ローン申請</u>が存在し、以下の属性が真の場合、
      -	_<u>借入限度額</u>_が空でない。
      -	_<u>借入希望額</u>_が空でない。
      -	_<u>借入限度額</u>_が_<u>借入希望額</u>_以上

      （アクション部）

      <u>住宅ローン申請</u>の_<u>承認可否</u>_をtrueに設定する。

    - ビジネスルール２’：[借入限度額の計算]

      （条件部）
      <u>住宅ローン申請</u>が存在し、以下の属性が真の場合、
      -	_<u>借入限度額</u>_が空である。
      -	_<u>返済期間</u>_が空でない。
      -	_<u>返済負担率</u>_が空でない。
      -	_<u>審査金利</u>_が空でない。
      かつ、<u>申請者</u>が存在し、以下の属性が真の場合、
      -	_<u>年収</u>_が空でない。

      （アクション部）

      （_<u>年収</u>_ × _<u>返済負担率</u>_）×（（１＋ _<u>審査金利</u>_）^（_<u>返済期間</u>_ –１））÷（_<u>審査金利</u>_ ×（１＋_<u>審査金利</u>_）^（_<u>返済期間</u>_））の計算結果を_<u>借入限度額</u>_として設定する。

    - ビジネスルール３’：[審査金利の設定]

      （条件部）
      <u>住宅ローン申請</u>が存在し、以下の属性が真の場合、
      -	_<u>審査金利</u>_が空である。

      （アクション部）

      _<u>審査金利</u>_に0.04を設定する。

    - ビジネスルール４’：[返済負担率の決定]

      （条件部）
      <u>住宅ローン申請</u>が存在し、以下の属性が真の場合、
      -	_<u>返済負担率</u>_が空である。
      かつ、<u>申請者</u>が存在し、以下の属性が真の場合、
      -	_<u>年収</u>_が[パラメータ１]以上である。
      -	_<u>年収</u>_が[パラメータ２]未満である。

      （アクション部）

      _<u>返済負担率</u>_は、[パラメータ３]を設定する。

      パラメータの決定表は以下のとおりとする。

||パラメータ１|パラメータ2|パラメータ3|
|:--|:--|:--|:--|
|説明|年収〜以上|年収〜未満|返済負担率|
|250万円未満||250|25|
|250万円以上400万円未満|250|400|30|
|400万円以上|400||35|

## データモデルの作成

1. ブラウザからhttp://localhost:8080/business-central　を開きます。
        ログイン名：demo[1-5] パスワード：jbossbrms1!

1. [オーサリングメニュー]を選択すると、プロジェクトエクスプローラーが開きます。このプロジェクトは、Loan とApplicantの単純なデータモデルと、クレジットスコアルールのディシジョンテーブルが存在します。

1. [新しいアイテム]->[データオブジェクト]を選択し、申請者のデータオブジェクト”Applicant”として作成します。（データオブジェクト名は英数字のみのため）

  ![img01](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson01.png)

1. [add field]ボタンをクリックして、下図のように属性を設定します。

  ![img02](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson02.png)

1. 設定が終わったら画面の上部にある[保存]ボタンをクリックして変更を保存します。

  ![img03](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson03.png)

1. JBoss BRMSでは、すべての変更にコメントを付けて記録することができます。同様に、住宅ローン申請を”Loan”として作成します。

  ![img04](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson04.png)

## ビジネスルールの作成

次にビジネスルールを作成します。

### 【ビジネスルール１：承認可否の判定】

1. [新しいアイテム]->[ガイド付きルール]を選択し、名前を”承認可否の判定”として作成します。

  ![img05](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson05.png)

1. ルール作成画面のWHENの行の右端に＋マークがありますので、クリックします。

  ![img06](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson06.png)

1. [条件をルールに追加]ダイアログが開きますので、”Loan”を選択してOKボタンをクリックします。

  ![img07](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson07.png)

1. [Loanがあります]をクリックして、[Loanへの制約変更]ダイアログを開きます。

  ![img08](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson08.png)

1. [フィールドに制約を追加]のドロップダウンリストより、”amount”を選択します。

  ![img09](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson09.png)

1. [amount]の横にドロップダウンリストが表示されるので、”は空でない”を選択します。

  ![img10](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson10.png)

1. 再度[次を含むLoanがあります。] をクリックして、「maxAmountは空でない」という条件を追加します。さらに”amount”を追加し、ドロップダウンリストから”は次の値以下：”を選択します。その後、ドロップダウンリストの右にある鉛筆アイコンをクリックします。

  ![img11](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson11.png)

1. フィールド値ダイアログで、[新規フォーミュラ]ボタンをクリックします。

  ![img12](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson12.png)

1. ドロップダウンリストの右に新しいフィールドが表示されるので、”maxAmount”と入力します。

  ![img13](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson13.png)

1. アクション句（THEN句）でLoanオブジェクトを参照するためにバインド変数を定義します。再度[次を含むLoanがあります]をクリックし、変数名に”loan”を入力して、[設定]ボタンをクリックします。

  ![img14](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson14.png)

1. 今度はTHEN句の右端にある＋をクリックします。

  ![img15](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson15.png)

1. [新規アクションを追加]ダイアログで”Loanのフィールド値を変更”を選択します。

  ![img16](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson16.png)

1. 鉛筆アイコンをクリックします。

  ![img17](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson17.png)

1. フィールドを追加ダイアログで、”approved”を選択します。

  ![img18](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson18.png)

1. approvedの右側にある、新たな鉛筆アイコンをクリックします。

  ![img19](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson19.png)

1. フィールド値ダイアログで、[固定値]ボタンをクリックし、値を”true”に設定します。

  ![img20](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson20.png)

1. これでルールが作成できました。[ソース]タブをクリックするとDRLが確認できます。

  ![img21](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson21.png)

以上のように簡単なビジネスルールは、ガイド付きルールで作成します。

### 【ビジネスルール２：借入限度額の計算】

1. 借入限度額は計算式が複雑なため、直接DRL形式で作成します。[新しいアイテム]->[DRLファイル]を選択し、ルール名を”借入限度額の計算”として作成します。DRLエディターが表示されますので、以下のDRLをコピーして保存してください。

  ```借入限度額の計算.drl
  package com.redhat.loandemo;
  import java.math.BigDecimal;
  import java.math.MathContext;

  rule "借入限度額の計算"
  enabled true
  when
    loan : Loan( maxAmount == null, duration != null, debtRatio != null, interestRate != null )
    applicant : Applicant(salary != null)
  then
    loan.setMaxAmount(BigDecimal.valueOf(applicant.getSalary())
    .multiply(loan.getDebtRatio().divide(new BigDecimal("100"), 2, BigDecimal.ROUND_HALF_UP))
    .multiply(loan.getInterestRate().add(new BigDecimal("1.00"))
    .pow(loan.getDuration() - 1, new MathContext(2)))
    .divide(loan.getInterestRate().multiply(loan.getInterestRate().add(new BigDecimal("1.00"))
    .pow(loan.getDuration(), new MathContext(2))), 2, BigDecimal.ROUND_HALF_UP));
    update(loan);
  end
  ```

1. [検証]ボタンをクリックして、記述が正しいことを確認してください。

  ![img22](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson22.png)


### 【ビジネスルール３：審査金利の設定】

1. ビジネスルール１の要領に従い、審査金利の設定ルールを以下のように設定します。

  ![img23](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson23.png)

1. ただし今回アクション句(THEN句)は、”Loanのフィールド値を変更”ではなく、”更新Loan”を選択します。

  ![img24](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson24.png)

1. ここでビジネスルール１と違う点に注意してください。（なぜ異なるのかは、「コラム：作成したビジネスルールの内部動作」で説明します。）
ソースを確認すると、アクション句にmodify関数が使用されているのを確認しましょう。

  ![img25](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson25.png)

### 【ビジネスルール４：返済限度額の決定】

1. 最後にディシジョンテーブルを利用した、返済限度額の決定ルールを作成します。[新しいアイテム]->[ガイド付きディシジョンテーブル]を選択し、”返済限度額の決定”と名前をつけて作成します。以下のような空のディシジョンテーブルが表示されますので、上部にある、ディシジョンテーブルの＋アイコンをクリックします。

  ![img26](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson26.png)

1. 以下のようなエントリーが表示されますので、＋新規カラムをクリックします。

  ![img27](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson27.png)

1. [新規カラムを追加]ダイアログが表示されますので、”簡単な条件を追加”を選択します。

  ![img28](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson28.png)

1. [条件カラムの設定]ダイアログが表示されますので、上部の[パターン]の右にある鉛筆アイコンをクリックします。

  ![img29](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson29.png)

1. [新規ファクトパターンを作成]ダイアログで以下のように設定します。

  ![img30](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson30.png)

1. [フィールド]に”salary”、[オペレータ]に”は次の値以上:”、[カラムヘッダー（説明）]に”年収〜以上”と入力し、OKボタンをクリックします。

  ![img31](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson31.png)

1. 以下のように新しい条件カラムが追加されることを確認してください。

  ![img32](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson32.png)

1. 同様に、次の条件カラムを追加します。ファクトタイプには先ほど作成したパターンが表示されますので、それを選択します。[パターン]: Applicant [applicant]

  ![img33](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson33.png)

1. [フィールド]に”salary”、[オペレータ]に”は次の値よりも小さい:”、[カラムヘッダー（説明）]に”年収〜未満”と入力し、OKボタンをクリックします。

1. さらに新規ファクトパターンを条件カラムに追加します。ファクトタイプ：Loan、バインディング: loanと入力してください。

  ![img34](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson34.png)

1. [フィールド]に”debtRatio”、[オペレータ]に”は空”、[カラムヘッダー（説明）]に”未計算”と入力し、OKボタンをクリックします。次のような画面になります。

  ![img35](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson35.png)

1. 次にアクションカラムを追加します。[新規カラムを追加]ダイアログで、[フィールド値をセット]を選択します。

  ![img36](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson36.png)

1. [カラム設定（ファクトにフィールドをセット）]ダイアログで、
[ファクト]:loan、[フィールド]:debtRatio、[カラムヘッダー（説明）]:返済限度額、[（オプション）値のリスト]: 25, 30, 35、[変更でエンジンを更新]をチェックします。

  ![img37](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson37.png)

1. これでディシジョンテーブルのひな形ができました。次に実際のビジネスルールを定義します。下部にある[行を追加]ボタンをクリックします。

  ![img38](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson38.png)

1. 下図のようにパラメータを入力してください。

  ![img39](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson39.png)

このように、同じ条件とアクションのパターンでパラメータだけが異なるようなビジネスルールを定義するには、ディシジョンテーブルが最適です。

これで全てのビジネスルールが完成しました。

  ```
  コラム：作成したビジネスルールの内部動作
  BRMSは、ファクトデータ（データモデルで作成したデータオブジェクト）を管理する「ワーキングメモリー」と、ビジネスルールを管理する「プロダクションメモリー」の相互作用によりビジネスルールを実行しています。ファクトデータが新規に挿入されるか、更新されたタイミングで、ビジネスルールにファクトデータがマッチするかどうかを判断します（パターンマッチング）。マッチしたビジネスルールとファクトデータのセットは「アクティベート」された状態として、「アジェンダ」と呼ばれる領域に格納されます。その後「ファイヤー」と呼ばれる命令により、アジェンダにリストされたビジネスルールのアクションが順番に実行されます。
  　今回、ビジネスルール１以外、updateまたはmodifyという関数によりファクトデータの変更を行っている理由は、そのタイミングでビジネスルールの「再評価」を行い、新たにマッチするビジネスルールを見つけるためです。
  　この動きをビジネスルールの「前向き推論（forward chaining）」と呼び、BRMSプログラミングにおける、大きな特徴の一つです。
  ```

## ビジネスルールのテスト

1. それではこれらのビジネスルールが正しく動作しているかテストしてみましょう。[新しいアイテム]->[テストシナリオ]を選択し、”年収500万借入限度額3000万の場合”という名前のテストシナリオを作成します。

  ![img40](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson40.png)

1. 入力データを作成します。以下の＋アイコンをクリックしてください。

  ![img41](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson41.png)

1. 新規ファクトとして”Applicant”を選択し、ファクト名に”applicant”と入力して、[追加]ボタンをクリックします。

  ![img42](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson42.png)

1. [挿入 ‘Applicant’[applicant]]というエントリーが追加されました。その下にある、[フィールドを追加]をクリックします。

  ![img43](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson43.png)

1. [追加するフィールドを選択]ダイアログで”salary”を選択します。

  ![img44](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson44.png)

1. “salary”の右にある鉛筆アイコンをクリックし、固定値として”500”を入力します。

  ![img45](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson45.png)

1. 同様に、入力データとしてLoanを追加し、以下のようにduration: 30, amount: 3000を入力します。

  ![img46](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson46.png)

1. 次に期待値を入力します。期待値の＋アイコンをクリックしてください。

  ![img47](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson47.png)

1. [新規期待値]ダイアログで、[ファクト値]フィールドで”loan”を選択し、追加ボタンをクリックしてください。

  ![img48](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson48.png)

1. [Loan ‘loan’は以下の値を持つ]という表示をクリックします。

  ![img49](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson49.png)

1. 以下のように、maxAmount: 4238.28, debtRatio: 35, interestRate: 0.04, approved: trueを入力してください。

  ![img50](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson50.png)

1. これでテストシナリオができました。画面上部にある、[シナリオを実行]ボタンをクリックして結果を確認します。以下のように、[Reporting]ペインに「成功」と表示されることを確認してください。

  ![img51](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson51.png)

## ビジネスルールのデプロイ

1. [プロジェクトエディターを開く]ボタンをクリックし、下図のように右上のビルドメニューから[ビルド＆デプロイ]を選択して、プロジェクトのバージョン1.0をビルドします。

  ![img52](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson52.png)

1. [オーサリング] -> [アーティファクトリポジトリ]を参照し、loandemo-1.0.jar がデプロイされていることを確認します。

1. [デプロイ] -> [ルールのデプロイメント]を開きます。
既に ”local-server-123”という名前のサーバーが登録されています。

  ![img53](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson53.png)

1. このサーバーエントリーの一番右端にある＋をクリックし、新しくコンテナを作成します。
  - 1番目のフィールド: loandemo
  - [Search] ボタンをクリックすると利用可能なアーティファクトの一覧が表示されるので、loandemo-1.0 の[Select]ボタンを押して選択します。
  - [OK]ボタンをクリックします。

  ![img54](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson54.png)

1. コンテナが作成されると、”loandemo”というエントリーが表示されます。一番右側のアイコンをクリックして詳細を表示します。

  ![img55](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson55.png)

1. loandemo の左にある丸印をクリックし、画面右上の[Start]をクリックします。オレンジ色が緑色になったら正常に起動しています。これで準備は完了です。

## ビジネスルールの呼出

1. RESTが呼び出せるクライアントで実際に呼び出してみます。本書ではFirefoxブラウザにプラグインできる、RESTClientを利用します。

  - [Authentication] -> [Basic Authentication]メニューを選択して認証情報を追加します。

    ユーザー名: demo[1-5] パスワード: jbossbrms1!

  - [Headers] -> [Custom Header]メニューを選択し、以下のヘッダー情報を追加します。

    - Name: X-KIE-ContentType, Value: xstream
    - Name: Content-Type, Value: application/xml
    - Method: GETで、以下の URLを呼び出すと、利用可能なコンテナのリストが返ってきます。
      http://localhost:8080/kie-server/services/rest/server/containers

  - 下図のようにloandemoがサーバーで利用可能なことが確認できます。

  ![img56](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson56.png)

1. POSTメソッドにより以下のURLを呼び出すことでBRMSを呼び出します。
	 - http://localhost:8080/kie-server/services/rest/server/containers/instances/loandemo

1. 以下のXMLファイルをBodyにコピーします。

  ```body
  <batch-execution lookup="defaultStatelessKieSession">
    <insert out-identifier="applicant" return-object="true">
      <com.redhat.loandemo.Applicant>
        <name>あなたの名前</name>
        <salary>あなたの年収</salary>
      </com.redhat.loandemo.Applicant>
    </insert>
      <insert out-identifier="loan" return-object="true">
      <com.redhat.loandemo.Loan>
        <amount>3000</amount>
        <duration>30</duration>
      </com.redhat.loandemo.Loan>
    </insert>
    <fire-all-rules out-identifier="myFireCommand"/>
  </batch-execution>
  ```

1. BRMSにより評価された結果がResponseフィールドに表示されます。Loanオブジェクトの<approval>タグが戻ってくることを確認します。

## ビジネスルールの変更

1. ディシジョンテーブルを変更して、新規バージョンとしてデプロイします。

  ![img57](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson57.png)

1. [プロジェクトエディター]で、バージョンを”1.1”に変更してビルドします。

  ![img58](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson58.png)

1. [サーバー管理ブラウザ]でloandemoコンテナを開き、Release IdのVersionに”1.1”を入力して、 [Upgrade]ボタンをクリックします。これでコンテナのバージョンがアップグレードされました。

  ![img59](https://raw.githubusercontent.com/kkomazaw/brms-loan-realtime-decision-server-demo/master/docs/demo-images/handson59.png)

1. 再度RESTClientでルールを呼び出し、結果が変わることを確認します。

以上ですべてのハンズオンが終了しました。

## 補足資料：事前準備

### 【BRMSサーバー側の準備】

1. 	https://github.com/kkomazaw/brms-loan-realtime-decision-server-demoをダウンロードして任意の場所に展開します。

1. installsディレクトリのREADMEに記載されているソフトウェアをダウンロードし、installsディレクトリにコピーします。

1. プロジェクトのルートディレクトリに移動し、”init.sh” または “init.bat” ファイルを実行します。（Windowsの場合は管理者権限で実行してください。）
1. ./target/jboss-eap-6.4/bin/standalone.shを実行してEAPを起動します。

### 【クライアントPC側の準備】
1. Firefoxを開き、以下のURLより RESTClientプラグインを追加します。https://addons.mozilla.org/ja/firefox/addon/restclient/

1. BRMSサーバーが起動した後、以下のURLよりBusiness Centralのホームページにアクセスできることを確認します。
http://<BRMSサーバーのホスト名>:8080/business-central

以上
