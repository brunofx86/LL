(* This file is part of the Linear Logic formalization in Coq:
https://github.com/brunofx86/LL *)

(** ** Linear Logic Sequent Calculi
We formalize different sequent calculi for Classical Linear Logic: two
sided, one sided and dyadic systems. Some systems also make explicit
the measures (e.g., height of derivation) needed for the
cut-elimination proof.

All the systems internalize the exchange rule. For instance,
the typical rule for [⊤] 
<< 
--------------- ⊤ 
|-- Gamma , ⊤ 
>>

is defined as

[ forall Gamma M, Gamma =mul= {{Top}} U M -> |-- Gamma ]

The considered systems are: 

 - [cls] (notation [D |-- L]): two sided system without cut rule. 
   Structural rules (weakening and contraction)
   are explicit in the system (see e.g., [cls_questc]).

 - [sig1] (notation [|-- L]): one sided system without cut
   rule. Structural rules (weakening and contraction) are explicit in
   the system.

 - [sig2] (notation [|-- B ; L]): dyadic, one sided system without cut
   rule. [B] is the classical context and [L] the
   linear context. There are no structural rules. Those rules are
   proved to be admissible in the classical context (see e.g., Theorem
   [height_preserving_weakning_sig2h]).

 - [sig2h] (notation [n |-- B ; L]): similar to [sig2] but the height
   of the derivation [n] is explicit. This is useful in proofs that
   require induction on the height of the derivation.

 - [sig2hc] (notation [n '|-c' B ';' L]): dyadic, one sided system
   with cut rule.

 - [sig2hcc] (notation [n '|-cc' B ';' L]): adds to [sig2hc] the
   following cut rule (for the classical context)

<<
|-- B; M, !F   |-- B, F° ; N
----------------------------- CCUT
|-- B ; M, N
>>

  - [sig3] (notation [n => c ; B ; L]) : where we make explicit the
    number of times the cut rules (CUT or CCUT) were used in the
    derivation. It makes also explicit the measures used in the proof
    of cut-elimination: height of the cut and complexity of the cut
    formula (see [sig3_cut_general]).

  - [TriSystem] (notation [ |-F- B ; L ; UP L ] for the negative phase and
    [ |-F- B ; L ; DW F ] for the positive phase). This system implements
    the focused system for linear logic as described by 
    #<a href="https://www.cs.cmu.edu/~fp/courses/15816-s12/misc/andreoli92jlc.pdf"> Andreoli </a>#.

 *)


(*Add LoadPath "../". *)
Require Export StrongInduction.
Require Export Permutation.
Require Export SyntaxLL.
Require Import Coq.Relations.Relations.
Require Import Coq.Arith.EqNat.
Require Import Coq.Classes.Morphisms.
Require Import Coq.Setoids.Setoid.
Require Export Coq.Sorting.PermutSetoid.
Require Export Coq.Sorting.PermutEq.
Require Import Coq.Program.Equality.
Require Import Coq.Logic.FunctionalExtensionality.
Require Import Eqset.

Set Implicit Arguments.


Module SqSystems (DT : Eqset_dec_pol).
  
  Module Export SxLL := FormulasLL DT.
  Export DT.

  Hint Resolve Max.le_max_r. 
  Hint Resolve Max.le_max_l.
  Hint Constructors IsNegativeAtom.
  Hint Constructors IsPositiveAtom.

  
  (****** ARROWS ******)
  Inductive Arrow  :=
  | UP (l : list Lexp)
  | DW (F : Lexp).
  
  Definition Arrow2LL (A: Arrow) : list Lexp :=
    match A  with
    | UP l => l
    | DW F => [F]
    end.
  
  Lemma Arrow_eq_dec : forall F1 F2: Arrow , {F1 =F2} + {F1 <> F2}.
    intros.
    destruct F1;destruct F2.
    generalize(list_eq_dec FEqDec l l0);intro.
    destruct H;subst;auto. right; intuition. apply n;intuition. inversion H;auto.
    right;intro. inversion H.
    right;intro. inversion H.
    generalize(FEqDec F F0);intro.
    destruct H;subst;auto. right;intuition. apply n;inversion H;auto.
  Qed.
  

  (******************************************************)
  (** Triadic system *)
  (******************************************************)
  Reserved Notation " '|-F-' B ';' L ';' X " (at level 80).
  
  Inductive TriSystem:  list Lexp -> list Lexp -> Arrow -> Prop :=
  | tri_init1 : forall B A, IsNegativeAtom A ->  |-F- B ; [(Dual_LExp A)] ; DW (A)
  | tri_init2 : forall B B' A, IsNegativeAtom A -> B =mul= (Dual_LExp A) :: B' -> |-F- B ; [] ; DW (A)
  | tri_one : forall B, |-F- B ; [] ; DW 1
  | tri_tensor : forall B M N MN F G,
      MN =mul= M ++ N -> |-F- B ; N ; DW F -> |-F- B ; M ; DW G -> |-F- B ; MN ; DW (F ** G)
  | tri_plus1 : forall B M F G, |-F- B ; M ; DW F -> |-F- B ; M ; DW (F ⊕ G)
  | tri_plus2 : forall B M F G, |-F- B ; M ; DW G -> |-F- B ; M ; DW (F ⊕ G)
  | tri_bang : forall B F, |-F- B ; [] ; UP [F] -> |-F- B ; [] ; DW (! F)
  | tri_rel : forall B F L, Release F -> |-F- B ; L ; UP [F] ->  |-F- B ; L ; DW F
                                                                                 
  | tri_top : forall B L M, |-F- B ; L ; UP (Top :: M)
  | tri_bot : forall B L M, |-F- B ; L ; UP M -> |-F- B ; L ; UP (Bot :: M)
  | tri_par : forall B L M F G, |-F- B ; L ; UP (F::G::M) -> |-F- B ; L ; UP(F $ G :: M)
  | tri_with : forall B L M F G,
      |-F- B ; L ; UP (F :: M) -> |-F- B ; L ; UP (G :: M) -> |-F- B ; L ; UP (F & G :: M)
  | tri_quest : forall B L M F, |-F- B ++ [F] ; L ; UP M -> |-F- B ; L ; UP (? F :: M)
  | tri_store : forall B L M F, ~ Asynchronous  F-> |-F- B ; L ++ [F] ; UP M -> |-F- B ; L ; UP (F::M)
  | tri_dec1 : forall B L L' F, ~IsPositiveAtom F -> L =mul= F :: L' -> |-F- B ; L' ; DW F ->|-F- B ; L ; UP []
  | tri_dec2 : forall B B' L  F, ~IsPositiveAtom F -> B =mul= F :: B' -> |-F- B ; L ; DW F -> |-F- B ; L ; UP []
  | tri_ex  : forall B FX M t, |-F- B; M ; DW (Subst FX t) -> |-F- B; M ; DW (E{FX})
  | tri_fx  : forall B L FX M,    (forall x, |-F- B ; L ; UP( (Subst FX x) ::  M)) -> |-F- B ; L ; UP (F{FX} :: M)
  where " '|-F-' B ';' L ';' X " := (TriSystem B L X).
  Hint Constructors TriSystem.
  
  (******************************************************)
  (** Triadic system with meassures *)
  (******************************************************)
  Reserved Notation " n '|-F-' B ';' L ';' X " (at level 80).
  Inductive TriSystemh: nat -> list Lexp -> list Lexp -> Arrow -> Prop :=
  | trih_init1 : forall B A,  IsNegativeAtom A ->  0 |-F- B ; [(Dual_LExp A)] ; DW (A)
  | trih_init2 : forall B B' A,  IsNegativeAtom A -> B =mul= (Dual_LExp A) :: B' -> 0 |-F- B ; [] ; DW (A)
  | trih_one : forall B, 0 |-F- B ; [] ; DW 1
  | trih_tensor : forall B M N MN F G n m,
      MN =mul= M ++ N -> n |-F- B ; N ; DW F -> m |-F- B ; M ; DW G -> S (max n m) |-F- B ; MN ; DW (F ** G)
  | trih_plus1 : forall B M F G n, n |-F- B ; M ; DW F -> S n |-F- B ; M ; DW (F ⊕ G)
  | trih_plus2 : forall B M F G n, n |-F- B ; M ; DW G -> S n |-F- B ; M ; DW (F ⊕ G)
  | trih_bang : forall B F n, n |-F- B ; [] ; UP [F] -> S n |-F- B ; [] ; DW (! F)
  | trih_rel : forall B F L n, Release F -> n |-F- B ; L ; UP [F] ->  S n |-F- B ; L ; DW F
                                                                                          
  | trih_top : forall B L M, 0 |-F- B ; L ; UP (Top :: M)
  | trih_bot : forall B L M n, n |-F- B ; L ; UP M -> S n |-F- B ; L ; UP (Bot :: M)
  | trih_par : forall B L M F G n, n |-F- B ; L ; UP (F::G::M) -> S n |-F- B ; L ; UP(F $ G :: M)
  | trih_with : forall B L M F G n m,
      n |-F- B ; L ; UP (F :: M) -> m |-F- B ; L ; UP (G :: M) -> S (max n m) |-F- B ; L ; UP (F & G :: M)
  | trih_quest : forall B L M F n, n |-F- B ++ [F] ; L ; UP M -> S n |-F- B ; L ; UP (? F :: M)
  | trih_store : forall B L M F n, ~ Asynchronous F-> n |-F- B ; L ++ [F] ; UP M -> S n |-F- B ; L ; UP (F::M)
  | trih_dec1 : forall B L L' F n, ~IsPositiveAtom F -> L =mul= F :: L' -> n |-F- B ; L' ; DW F -> S n |-F- B ; L ; UP []
  | trih_dec2 : forall B B' L  F n, ~IsPositiveAtom F -> B =mul= F :: B' -> n |-F- B ; L ; DW F -> S n |-F- B ; L ; UP []
  | trih_ex  : forall B  n FX M t, 
      n |-F- B; M ; DW (Subst FX t) -> S n |-F- B; M ; DW (E{FX})
  | trih_fx  : 
      forall B L n FX M,
        (forall x : Term, n |-F- B ; L ; UP( (Subst FX x) ::  M)) -> S n |-F- B ; L ; UP (F{FX} :: M)
  where " n '|-F-' B ';' L ';' X " := (TriSystemh n B L X).
  Hint Constructors TriSystemh.
  
  Theorem AdequacyTri1 : forall n B M X, n |-F- B ; M ; X -> |-F- B ; M ; X.
    induction n using strongind;intros. 
    + inversion H;subst;eauto.
    (* inversion H0;subst;eauto. solves everything but it takes almost 1 min *)
    + inversion H0;subst.
      eapply tri_tensor;eauto.
      eapply tri_plus1;eauto.
      eapply tri_plus2;eauto.
      eapply tri_bang;eauto.
      eapply tri_rel;eauto.
      eapply tri_bot;eauto.
      eapply tri_par;eauto.
      eapply tri_with;eauto.
      eapply tri_quest;eauto.
      eapply tri_store;eauto.
      eapply tri_dec1;eauto.
      eapply tri_dec2;eauto.
      eapply tri_ex;eauto.
      eapply tri_fx;eauto.
  Qed.

  (**
Since there are no free variables in our encoding, we cannot prove
directly the usual substitution lemma: if there is a proof with a
fresh variable x, then there is a proof, of the same height for any
term t. The following axiom (and the similar ones for the other
systems) are introduced to cope with proofs of the form:

<<
H: forall x:Term, exists n:nat, |- Gamma, Subst FX x
----------------------------------------------------
G: exists n:nat, |- Gamma, F{ FX}
>>

The hypothesis [H] results in inductive proofs where the principal
formula is (the LL universal quantifier} [F{ FX}]. Note that we cannot
conclude the goal [G] from [H] since our hypothesis is weaker than the
similar one in pencil/paper proofs. More precisely, in a paper proof,
we can generalize [H] with a fresh variable [x]. Then, there exists
[n] s.t.  [n |- Gamma, Subst Fx x]. By using the substitution lemma,
for any [y], it must be the case [n |- Gamma, Subst Fx y] and we can
easily conclude the goal [G].
   *)
  Axiom ax_subs_prop: forall B L M FX (P:nat -> Prop), (forall x : Term, exists n : nat, (P n) /\ n |-F- B; L; UP (Subst FX x :: M)) -> exists n, (P n) /\ forall x, n |-F- B; L; UP (Subst FX x :: M) .

  Theorem ax_subs_prop' : forall B L M FX , (forall x : Term, exists n : nat, n |-F- B; L; UP (Subst FX x :: M)) -> exists n, forall x, n |-F- B; L; UP (Subst FX x :: M) .
    intros.
    assert(Hs: forall x : Term, exists n : nat, ((fun _ => True) n) /\ n |-F- B; L; UP (Subst FX x :: M)).
    intro x.
    generalize (H x) ; intro Hx.
    destruct Hx.
    eexists;eauto.
    apply ax_subs_prop in Hs.
    destruct Hs as [n [Hs Hs']].
    eexists. intro x.
    apply Hs'.
  Qed.

  Theorem AdequacyTri2 : forall B M X, |-F- B ; M ; X ->  exists n, n |-F- B ; M ; X.
    intros.
    induction H;try( destruct IHTriSystem);try( destruct IHTriSystem1); try( destruct IHTriSystem2); eauto.
    apply ax_subs_prop' in H0.
    destruct H0.
    exists (S x).
    apply trih_fx.
    intro.
    apply H0.
  Qed.

  
  
  (** The [B] and [M] contexts can be substituted by equivalent multisets *)
  Theorem TriExchangeh : forall B B' M M' X n, n |-F-  B ; M ; X -> B =mul= B' -> M =mul= M' -> n |-F- B' ; M' ; X.
  Proof.
    intros.
    generalize dependent B.
    generalize dependent M.
    generalize dependent B'.
    generalize dependent M'.
    generalize dependent X.
    induction n using strongind;intros.
    + inversion H;subst.
      ++ apply MulSingleton in H1;subst.
         eapply trih_init1;auto.
      ++ apply meq_sym in H1.
         apply  multiset_meq_empty in H1;subst.
         eapply trih_init2;eauto.
      ++
        apply meq_sym in H1.
        apply  multiset_meq_empty in H1;subst.
        eapply trih_one.
      ++
        eapply trih_top.
    +  inversion H0;subst.
       ++ (* tensor *)
         apply H  with (M':=N) (B':= B') in H5;auto.
         apply H  with (M':=M0) (B':= B') in H6;auto.
         apply trih_tensor with (F:=F)(G:=G) (N:=N)(M:=M0);auto.
         rewrite <- H1.
         assumption.
       ++ (* Oplus *) 
         eapply H  with (M':=M') (B':=B')in H4;auto.
       ++ (* Oplus 2*)
         eapply H  with (M':=M') (B':=B')in H4;auto.
       ++ (* Bang *)
         apply meq_sym in H1.
         apply  multiset_meq_empty in H1;subst.
         eapply H  with (B':=B')in H4;auto.
         eapply trih_bang;auto.
       ++ (* Release *)
         eapply H  with (M':=M') (B':=B')in H5;auto.
       ++ (* Bottom *)
         eapply H  with (M':=M') (B':=B')in H4;auto.
       ++ (* Par *)
         eapply H  with (M':=M') (B':=B')in H4;auto.
       ++ (* with *)
         eapply H  with (M':=M') (B':=B')in H4;auto.
         eapply H  with (M':=M') (B':=B')in H5;auto.
       ++ (* ? *)
         eapply H  with (M':=M')(B':=B' ++ [F])in H4;auto.
       ++  (* store *)
         eapply H  with (M':=M' ++ [F]) (B':=B')in H5;auto.
       ++  (* decide 1*)
         eapply H  with (M':= L' ) (B':=B')in H6;auto.
         eapply trih_dec1 with (F:=F);auto.
         rewrite <- H1.
         apply H5.
         assumption.
       ++ (* decide 2 *)
         eapply H  with (M':= M' ) (B':=B')in H6;auto.
         eapply trih_dec2 with (F:=F);auto.
         rewrite <- H2.
         apply H5.
       ++ (* exists *)
         eapply H  with (M':= M' ) (B':=B')in H4;auto.
         eapply trih_ex;eauto.
       ++ (* forall *)
         eapply trih_fx;auto ;intro.
         generalize (H4 x);intros.
         eapply H  with (M':=  M' ) (B':=B')in H3;auto.
  Qed.



  Generalizable All Variables.
  Instance trih_morphh : Proper (meq ==> meq ==> eq ==> iff) (TriSystemh n).
  Proof. 
    intros n A B Hab C D Hcd X Y Hxy; subst.
    split;intro.
    + apply TriExchangeh with (B:=A) (M:=C);auto.
    + apply TriExchangeh with (B:=B) (M:=D);auto.
  Qed.
  Instance trih_morph' : Proper (meq ==> meq ==> @eq Arrow ==> iff) (TriSystemh n).
  Proof. 
    intros n A B Hab C D Hcd X Y Hxy; subst.
    split;intro.
    + apply TriExchangeh with (B:=A) (M:=C);auto.
    + apply TriExchangeh with (B:=B) (M:=D);auto.
  Qed.

  
  Theorem TriExchange : forall B B' M M' X, |-F-  B ; M ; X -> B =mul= B' -> M =mul= M' -> |-F- B' ; M' ; X.
    intros.
    apply AdequacyTri2 in H.
    destruct H.
    rewrite H0 in H.
    rewrite H1 in H.
    eapply AdequacyTri1;eauto.
  Qed.

  
  
  Instance tri_morph : Proper (meq ==> meq ==> eq ==> iff) (TriSystem).
  Proof. 
    intros  A B Hab C D Hcd X Y Hxy; subst.
    split;intro.
    + apply TriExchange with (B:=A) (M:=C);auto.
    + apply TriExchange with (B:=B) (M:=D);auto.
  Qed.
  Instance tri_morph' : Proper (meq ==> meq ==> @eq Arrow ==> iff) (TriSystem).
  Proof. 
    intros A B Hab C D Hcd X Y Hxy; subst.
    split;intro.
    + apply TriExchange with (B:=A) (M:=C);auto.
    + apply TriExchange with (B:=B) (M:=D);auto.
  Qed.

  (** Dyadic System *)
  Reserved Notation " '|--' B ';' L" (at level 80).
  Inductive sig2: list Lexp -> list Lexp -> Prop :=

  | sig2_init : forall B L A, L =mul= (A ⁺) :: [A ⁻] -> |-- B ; L
  | sig2_one : forall B L, L =mul= [1] -> |-- B ; L 
  | sig2_top : forall B L M, L =mul= Top :: M -> |-- B ; L
  | sig2_bot : forall B L M , L =mul= Bot :: M -> |-- B ; M -> |-- B ; L
  | sig2_par : forall B L M F G , L =mul= (F $ G) :: M -> |-- B ; F :: G :: M -> |-- B ; L 
  | sig2_tensor : forall B L M N F G , 
      L =mul= (F ** G) :: (M ++ N)  ->
      |-- B ; F :: M ->
              |-- B ; G :: N ->  |-- B ; L
  | sig2_plus1: forall B L M F G , L =mul= (F ⊕ G) :: M -> |-- B ; F :: M -> |-- B ; L 
  | sig2_plus2: forall B L M F G , L =mul= (F ⊕ G) :: M -> |-- B ; G :: M -> |-- B ; L 
  | sig2_with: forall B L M F G , 
      L =mul= (F & G) :: M ->
      |-- B ; F :: M ->
              |-- B ; G :: M ->  |-- B ; L
  | sig2_copy: forall B D L M F , 
      D =mul= F :: B -> L =mul= F :: M ->
      |-- D ; L -> 
              |-- D ; M 

  | sig2_quest: forall B L M F , L =mul= (? F) :: M  ->
                                 |-- F :: B ; M -> 
                                              |-- B ; L
                                                        
  | sig2_bang: forall B F L , L =mul= [! F] ->
                              |--  B ; [F] ->
                                       |--  B ; L
  | sig2_ex  : forall B L FX M t,
      L =mul= E{FX} ::  M ->  |-- B ; (Subst FX t) :: M ->  |--  B ; L
  | sig2_fx  : forall B L FX M,  L =mul= (F{FX}) :: M -> (forall x, |-- B ; [Subst FX x] ++  M) ->  |-- B ; L
                                                                                                              
  where "|-- B ; L" := (sig2 B L).

  (** Exchange for the dyadic system *)
  Lemma sig2_der_compat : forall B1 B2 L1 L2 : list Lexp, B1 =mul= B2 -> L1 =mul= L2 -> |-- B1 ; L1 -> |-- B2 ; L2.
  Proof.
    intros B1 B2 L1 L2 PB PL H.
    revert dependent B2.
    revert dependent L2.  
    induction H; intros;
      try rewrite PB in *;
      try rewrite PL in *.
    eapply sig2_init; eassumption.
    eapply sig2_one; eassumption.
    eapply sig2_top; eassumption.
    assert (|-- B2 ; M) by solve [apply IHsig2; auto].
    eapply sig2_bot; eassumption.
    assert (|-- B2 ; (F :: G :: M)) by solve [apply IHsig2; auto].
    eapply sig2_par; eassumption.
    assert (|-- B2 ; F :: M) by solve [apply IHsig2_1; auto].
    assert (|-- B2 ; G :: N) by solve [apply IHsig2_2; auto].
    eapply sig2_tensor; eassumption.
    assert (|-- B2 ; F :: M) by solve [apply IHsig2; auto]. 
    eapply sig2_plus1; eassumption.
    assert (|-- B2 ; G :: M) by solve [apply IHsig2; auto]. 
    eapply sig2_plus2; eassumption.
    assert (|-- B2 ; F :: M) by solve [apply IHsig2_1; auto].
    assert (|-- B2 ; G :: M) by solve [apply IHsig2_2; auto].
    eapply sig2_with; eassumption.  
    assert (|-- B2 ; L) by solve [apply IHsig2; auto].
    eapply sig2_copy; eassumption.  
    assert (|-- F :: B2; M) by solve [apply IHsig2; auto].
    eapply sig2_quest; eassumption.  
    assert (|-- B2; [F]) by solve [apply IHsig2; auto].
    eapply sig2_bang; eassumption.
    (* exists *)
    eapply sig2_ex;eauto.
    (* forall *)
    eapply sig2_fx;eauto.
  Qed.

  Instance sig2_der_morphism :
    Proper (meq ==> meq ==> iff) (sig2).
  Proof.
    unfold Proper; unfold respectful. 
    intros B1 B2 PB L1 L2 PL.
    split; intro H.
    refine (sig2_der_compat PB PL H).
    refine (sig2_der_compat (symmetry PB) (symmetry PL) H).
  Qed.




  (** Dyadic system plus height of the derivation *)
  Reserved Notation " n '|--' B ';' L" (at level 80).
  Inductive sig2h: nat -> list Lexp -> list Lexp -> Prop :=
    
  | sig2h_init : forall B L A, L =mul= (A ⁺) :: [A ⁻] -> 0 |-- B ; L
  | sig2h_one : forall B L, L =mul= [1] -> 0 |-- B ; L 
  | sig2h_top : forall B L M, L =mul= Top :: M -> 0 |-- B ; L
  | sig2h_bot : forall B L M n, L =mul= Bot :: M -> n |-- B ; M -> S n |-- B ; L
  | sig2h_par : forall B L M F G n, L =mul= (F $ G) :: M -> n |-- B ; F :: G :: M -> S n |-- B ; L 
  | sig2h_tensor : forall B L M N F G n m, 
      L =mul= (F ** G) :: (M ++ N)  ->
      m |-- B ; F :: M ->
                n |-- B ; G :: N -> S (max n m) |-- B ; L
  | sig2h_plus1: forall B L M F G n, L =mul= (F ⊕ G) :: M -> n |-- B ; F :: M -> S n |-- B ; L 
  | sig2h_plus2: forall B L M F G n, L =mul= (F ⊕ G) :: M -> n |-- B ; G :: M -> S n |-- B ; L 
  | sig2h_with: forall B L M F G n m, 
      L =mul= (F & G) :: M ->
      m |-- B ; F :: M ->
                n |-- B ; G :: M -> S (max n m) |-- B ; L
  | sig2h_copy: forall B D L M F n, 
      D =mul= F :: B -> L =mul= F :: M ->
      n |-- D ; L ->  S n|-- D ; M 
                                   
  | sig2h_quest : forall B L M F n, L =mul= (? F) :: M  ->
                                    n |-- F :: B ; M ->   S n |-- B ; L
                                                                        
  | sig2h_bang : forall B F L n, L =mul= [! F] ->
                                 n |--  B ; [F] ->  S n |--  B ; L
                                                                   
  | sig2h_ex  : forall B L n FX M t,
      L =mul= E{FX} ::  M -> n |-- B ; (Subst FX t) :: M -> S n |--  B ; L
  | sig2h_fx  : forall B L n FX M,  L =mul= (F{FX}) :: M -> (forall x, n |-- B ; [Subst FX x] ++  M) -> S n |-- B ; L
                                                                                                                      
  where "n |-- B ; L" := (sig2h n B L).
  Hint Constructors sig2h.

  (** Exchange rule *)
  Lemma sig2h_der_compat : forall n B1 B2 L1 L2, B1 =mul= B2 -> L1 =mul= L2 -> n |-- B1 ; L1 -> n |-- B2 ; L2.
  Proof.
    intros n B1 B2 L1 L2 PB PL H.
    revert L1 L2 PL B1 B2 PB H;
      induction n using strongind; intros.
    - inversion H; subst. 
      +
        refine (sig2h_init _ (transitivity (symmetry PL) H0)). 
      +
        refine (sig2h_one _ (transitivity (symmetry PL) H0)).
      +
        refine (sig2h_top _ (transitivity (symmetry PL) H0)).
    - inversion H0; subst; try rewrite PL in H3; try rewrite PL in H2;
        try rewrite PB in H3; try rewrite PB in H2.
      +
        refine (sig2h_bot H2 _); auto.
        apply H with (L1:= M) (B1:=B1); auto.
      +
        refine (sig2h_par H2 _); auto.
        apply H with (L1:= F :: G :: M) (B1:=B1); auto.
      +
        refine (sig2h_tensor H2 _ _).
        apply H with (L1:= F :: M) (B1:=B1); auto.
        apply H with (L1:= G :: N) (B1:=B1); auto.
      +
        refine (sig2h_plus1 H2 _).
        apply H with (L1:= F :: M) (B1:=B1); auto. 
      +
        refine (sig2h_plus2 H2 _).
        apply H with (L1:= G :: M) (B1:=B1); auto. 
      +
        refine (sig2h_with H2 _ _).
        apply H with (L1:= F :: M) (B1:=B1); auto.
        apply H with (L1:= G :: M) (B1:=B1); auto.
      + 
        refine (sig2h_copy H2 H3 _).   
        apply H with (L1:= L) (B1:=B1); auto. 
      +
        refine (sig2h_quest H2 _).
        apply H with (L1:= M) (B1:= F :: B1); auto. 
      +
        refine (sig2h_bang H2 _).
        apply H with (L1:= [F]) (B1:=B1); auto.
      + (* exists *)
        eapply sig2h_ex;eauto.
      + (* forall *)
        eapply sig2h_fx;eauto.
        
  Qed.

  
  
  Lemma Sig2InitNegative:  forall B A, IsNegativeAtom A ->  |-- B; [A°; A].
    intros.
    inversion H;try(rewrite AtomNeg);try(rewrite AtomPos); eapply sig2_init;eauto.
  Qed.
  Lemma Sig2InitNegative':  forall B A, IsNegativeAtom A ->  |-- B; [A; A°].
    intros.
    inversion H;try(rewrite AtomNeg);try(rewrite AtomPos); eapply sig2_init;eauto.
  Qed.
  Lemma Sig2One: forall B, |-- B; [1].
    intro. apply sig2_one;auto.
  Qed.
  Lemma Sig2Top: forall B M M', |-- B; M ++ ⊤ :: M'.
    intros. eapply sig2_top;auto.
  Qed.
  Hint Resolve Sig2InitNegative Sig2InitNegative' Sig2One Sig2Top.

  Lemma StoreInv : forall B M L L' A, |-F- B; M; UP ((A ⁺ :: L) ++ L') -> |-F- B; M ++ [A ⁺]; UP ( L ++ L').
    intros.
    inversion H;subst;LexpContr;auto.
  Qed.
  Lemma StoreInv' : forall B M L L' A, |-F- B; M; UP (( A ⁻ :: L) ++ L') -> |-F- B; M ++ [A ⁻]; UP ( L ++ L').
    intros.
    inversion H;subst;LexpContr;auto.
  Qed.

  Lemma ParInv: forall B M L F G, |-F- B; M; UP (F $ G :: L) -> |-F- B; M; UP (F :: G :: L).
    intros.
    inversion H;subst; LexpContr.
    assert (F0 = F) by ( apply ParEq1 in H0;auto).
    assert (G0 = G) by ( apply ParEq2 in H0;auto).
    subst.
    auto.
    assert(Asynchronous (F $ G)) by auto. contradiction.
  Qed.

  Lemma TriTop : forall B M L, |-F- B ; M ; UP(⊤ :: L).
    auto.
  Qed.

  Hint Resolve TriTop StoreInv StoreInv'.

  Lemma StoreInversion : forall n B M F,  n |-F- B; M; UP [F] -> PosOrNegAtom F -> n -1 |-F- B ; M ++ [F] ; UP [].
    intros.
    inversion H;subst;try(inversion H0);subst;simpl;try(rewrite Nat.sub_0_r);auto.
  Qed.
  Lemma StoreInversionL : forall n B M N L,  n |-F- B; M; UP (N ++ L) -> LexpPos N -> exists m, m |-F- B ; M ++ N ; UP L.
    intros.
    generalize dependent M.
    generalize dependent n.
    induction N;intros.
    + simpl in *.
      eexists.
      rewrite app_nil_r.
      eauto.
    + inversion H;subst; try(
                             inversion H0;
                             simpl in H1;
                             intuition).
      apply H3 in H7.
      destruct H7.
      eexists.
      assert( (M ++ [a]) ++ N =mul=  M ++ a :: N) by solve_permutation.
      rewrite <- H5.
      eauto.
  Qed.

  Lemma Init1: forall B n x,
      true = isPositive n ->
      |-F- B; [fun T : Type => atom (a1 n (x T))]; DW (fun T : Type => perp (a1 n (x T))).
  Proof.
    intros.
    assert((fun T : Type => perp (a1 n (x T)))° = (fun T : Type => atom (a1 n (x T)))) by auto.
    rewrite <- H0.
    apply tri_init1. constructor;auto. 
  Qed.

  Lemma Init2: forall B n x,
      true = isPositive n ->
      |-F- B ++ [fun T : Type => atom (a1 n (x T))]; []; DW (fun T : Type => perp (a1 n (x T))).
  Proof.
    intros.
    assert((fun T : Type => perp (a1 n (x T)))° = (fun T : Type => atom (a1 n (x T)))) by auto.
    rewrite <- H0.
    eapply tri_init2;auto. constructor;auto.
  Qed.

  Lemma Init1': forall B n x y,
      true = isPositive n ->
      |-F- B; [fun T : Type => atom (a2 n (x T) (y T))]; DW (fun T : Type => perp (a2 n (x T) (y T))).
  Proof.
    intros.
    assert((fun T : Type => perp (a2 n (x T) (y T)))° =
           (fun T : Type => atom (a2 n (x T) (y T)))) by auto.
    rewrite <- H0.
    apply tri_init1. constructor;auto. 
  Qed.

  Lemma Init2': forall B n x y,
      true = isPositive n ->
      |-F- B ++ [fun T : Type => atom (a2 n (x T) (y T))]; [] ; DW (fun T : Type => perp (a2 n (x T) (y T))).
  Proof.
    intros.
    assert((fun T : Type => perp (a2 n (x T) (y T)))° =
           (fun T : Type => atom (a2 n (x T) (y T)))) by auto.
    rewrite <- H0.
    eapply tri_init2. constructor;eauto.
    solve_permutation.
  Qed.

  Lemma InitAtom : forall At B , IsPositiveAtom (At ⁺) ->  |-F- B; [At ⁺]; DW (At ⁻).
  Proof.
    intros.
    assert((At ⁻) ° = At ⁺) by reflexivity.
    rewrite <- H0.
    apply tri_init1.
    apply PositiveNegativeAtom;auto.
  Qed.


  Lemma InitAtom' : forall At B , IsNegativeAtom (At ⁺) ->  |-F- B; [At ⁻]; DW (At ⁺).
  Proof.
    intros.
    assert((At ⁺) ° = At⁻ ) by reflexivity.
    rewrite <- H0.
    apply tri_init1;auto.
  Qed.

  Lemma TopDown : forall M B, |-F- B ; M ; DW (Top).
    intros.
    apply tri_rel. constructor.
    apply tri_top.
  Qed.


  
  Ltac autoLexp :=
    simpl;
    try(match goal with [|- Release _] => try(auto using IsPositiveAtomRelease); try(constructor) end);
    try(auto using tri_init2, tri_init1, tri_top);
    try(auto using Init1, Init2,Init1', Init2', InitAtom, InitAtom',TopDown);
    try(
        match goal with [|- IsNegativeAtom _] => constructor;auto end );
    try(LexpContr);
    try(
        match goal with [|-~ Asynchronous _] =>
                        try(apply NotAsyncAtom);
                        try(apply NotAsyncAtom');
                        try(apply NotAsyncOne);
                        try(apply NotAsyncZero);
                        try(apply NotAsyncTensor);
                        try(apply NotAsyncPlus);
                        try(apply NotAsyncEx);
                        try(apply NotAsyncBang)
        end);
    try(
        match goal with [|- ~ IsPositiveAtom ?F] =>
                        try apply NotPATop;
                        try apply NotPABot;
                        try apply NotPAOne;
                        try apply NotPAZero;
                        try apply NotPATensor;
                        try apply NotPAPlus;
                        try apply NotPAWith;
                        try apply NotPAPar;
                        try apply NotPABang;
                        try apply NotPAQuest;
                        try apply NotPAExists;
                        try apply NotPAForall;
                        try(assert(HPosNeg: IsNegativeAtom F) by  (constructor;auto);
                            intro HisPos; apply PositiveNegative in HPosNeg;auto)
                           
        end);
    try(match goal with [H : ~ Asynchronous ?F |- _] => assert(Asynchronous F) by auto;contradiction
        end);
    invNegAtom;
    invRel.

  




  Lemma AppSingleton : forall (F G: Lexp) M, [F] = M ++ [G] -> M = [].
    intros.
    destruct M;auto.
    simpl in H.
    inversion H.
    contradiction_multiset.
  Qed.

  (** Automatization of focused proofs. This tactic solves most of the cases for checking polarities of atoms and also determining when a formula is positive or negative *)
  Ltac InvTac :=
    try(LexpSubst);
    try(LexpSubst);
    try(match goal with [ H : [?F] = ?M ++ [?G] |- _] =>
                        assert(M=[]) by (eapply AppSingleton;eauto);subst;
                        simpl in H;inversion H;subst;clear H
        end);
    try contradiction_multiset;
    try(match goal with [H1 : LexpPos ?M , H2 : ~ Asynchronous ?F |- LexpPos(?M ++ [?F])] => apply LexpPosConc ;auto end);
    try(match goal with [H1 : LexpPos ?M , H2 : ?M =mul= ?F :: ?L |- LexpPos(?L)] =>
                        rewrite H2 in H1 ; inversion H1 ;auto end);

    try(match goal with [H : _ (S ?n - 1) |- _] =>
                        let Hx := fresh "HF" in
                        assert(Hx : S n -1 = n) by omega;
                        rewrite Hx in H; clear Hx
        end);
    try(match goal with [H1 : true = isPositive ?n , H2 : false = isPositive ?n |- _] =>
                        rewrite <- H1 in H2 ;intuition end);
    autoLexp.

  



  (** This tactic solves (mostly automatically) the whole negative phase. *)
  Ltac NegPhase :=
    repeat (
        match goal with
        | [|- |-F- _ ; _ ; UP (?l :: ?L)] =>
          match l with
          | Atom _ => apply tri_store;InvTac
          | Perp _ => apply tri_store;InvTac
          | Top => apply tri_top;InvTac
          | Bot => apply tri_bot;InvTac
          | Zero => apply tri_store;InvTac
          | One => apply tri_store;InvTac
          | Tensor _ _ => apply tri_store;InvTac
          | Plus _ _ => apply tri_store;InvTac
          | Par _ _ => apply tri_par;InvTac
          | With _ _ => apply tri_with;InvTac;NegPhase
          | Bang _ => apply tri_store;InvTac
          | Quest _ => apply tri_quest;InvTac
          | Ex _ => apply tri_store;InvTac
          | Fx _ => apply tri_fx;InvTac;intro
          end
        end).
  
  (* Dyadic system with inductive measures *)
  Reserved Notation "n '|-c' B ';' L" (at level 80).
  Inductive sig2hc: nat -> list Lexp -> list Lexp -> Prop :=

  | sig2hc_init : forall B L A, L =mul= (A ⁺) :: [A ⁻] -> 0 |-c B ; L
  | sig2hc_one : forall B L, L =mul= [1] -> 0 |-c B ; L 
  | sig2hc_top : forall B L M, L =mul= Top :: M -> 0 |-c B ; L
  | sig2hc_bot : forall B L M n, L =mul= Bot :: M -> n |-c B ; M -> S n |-c B ; L
  | sig2hc_par : forall B L M F G n, L =mul= (F $ G) :: M -> n |-c B ; F :: G :: M -> S n |-c B ; L 
  | sig2hc_cut : forall B L M N F m n, 
      L =mul= (M ++ N)  ->
      m|-c B ; F :: M ->
               n|-c B ; F° :: N -> S (max n m)|-c B ; L
  | sig2hc_tensor : forall B L M N F G n m, 
      L =mul= (F ** G) :: (M ++ N)  ->
      m |-c B ; F :: M ->
                n |-c B ; G :: N -> S (max n m) |-c B ; L
  | sig2hc_plus1: forall B L M F G n, L =mul= (F ⊕ G) :: M -> n |-c B ; F :: M -> S n |-c B ; L 
  | sig2hc_plus2: forall B L M F G n, L =mul= (F ⊕ G) :: M -> n |-c B ; G :: M -> S n |-c B ; L 
  | sig2hc_with: forall B L M F G n m, 
      L =mul= (F & G) :: M ->
      m |-c B ; F :: M ->
                n |-c B ; G :: M -> S (max n m) |-c B ; L
                                                          
  | sig2hc_copy: forall B D L M F n, 
      D =mul= F :: B -> L =mul= F :: M ->
      n |-c D ; L -> 
                S n|-c D ; M 

  | sig2hc_quest : forall B L M F n, L =mul= (? F) :: M  ->
                                     n |-c F :: B ; M -> 
                                                    S n |-c B ; L
                                                                  
  | sig2hc_bang : forall B F L n, L =mul= [! F] ->
                                  n |-c  B ; [F] ->
                                             S n |-c  B ; L
                                                            
  | sig2hc_ex  : forall B L n FX M t,
      L =mul= E{FX} ::  M -> n |-c B ; (Subst FX t) :: M -> S n |-c  B ; L
  | sig2hc_fx  : forall B L n FX M,  L =mul= (F{FX}) :: M -> (forall x, n |-c B ; [Subst FX x] ++  M) -> S n |-c B ; L
                                                                                                                       
  where "n |-c B ; L" := (sig2hc n B L).

  Lemma sig2hc_der_compat : forall n (B1 B2 L1 L2 : list Lexp), B1 =mul= B2 -> L1 =mul= L2 -> n |-c B1 ; L1 -> n |-c B2 ; L2.
  Proof.
    intros n B1 B2 L1 L2 PB PL H.
    revert L1 L2 PL B1 B2 PB H;
      induction n using strongind; intros.
    - inversion H; subst. 
      +
        refine (sig2hc_init _ (transitivity (symmetry PL) H0)). 
      +
        refine (sig2hc_one _ (transitivity (symmetry PL) H0)).
      +
        refine (sig2hc_top _ (transitivity (symmetry PL) H0)).
    - inversion H0; subst; try rewrite PL in H3; try rewrite PL in H2;
        try rewrite PB in H3; try rewrite PB in H2.
      +
        refine (sig2hc_bot H2 _); auto.
        apply H with (L1:= M) (B1:=B1); auto.
      +
        refine (sig2hc_par H2 _); auto.
        apply H with (L1:= F :: G :: M) (B1:=B1); auto.
      +
        refine (sig2hc_cut H2 _ _).
        eapply H with (L1:= F :: M) (B1:=B1); auto.
        eapply H with (L1:= F° :: N) (B1:=B1); auto.
      +
        refine (sig2hc_tensor H2 _ _).
        apply H with (L1:= F :: M) (B1:=B1); auto.
        apply H with (L1:= G :: N) (B1:=B1); auto.
      +
        refine (sig2hc_plus1 H2 _).
        apply H with (L1:= F :: M) (B1:=B1); auto. 
      +
        refine (sig2hc_plus2 H2 _).
        apply H with (L1:= G :: M) (B1:=B1); auto. 
      +
        refine (sig2hc_with H2 _ _).
        apply H with (L1:= F :: M) (B1:=B1); auto.
        apply H with (L1:= G :: M) (B1:=B1); auto.
      + 
        refine (sig2hc_copy H2 H3 _).   
        apply H with (L1:= L) (B1:=B1); auto. 
      +
        refine (sig2hc_quest H2 _).
        apply H with (L1:= M) (B1:= F :: B1); auto. 
      +
        refine (sig2hc_bang H2 _).
        apply H with (L1:= [F]) (B1:=B1); auto. 
      + (* exists *)
        eapply sig2hc_ex;eauto.
      + (* forall *)
        eapply sig2hc_fx;eauto.   
  Qed.

  Generalizable All Variables.
  Instance sig2hc_der_morphism :
    Proper (meq ==> meq ==> iff) (sig2hc n).
  Proof.
    unfold Proper; unfold respectful. 
    intros n B1 B2 PB L1 L2 PL.
    split; intro H.
    refine (sig2hc_der_compat PB PL H).
    refine (sig2hc_der_compat (symmetry PB) (symmetry PL) H).
  Qed.
  
  (** System with rules Cut and Cut! *)
  Reserved Notation " n '|-cc' B ';' L" (at level 80).
  Inductive sig2hcc: nat -> list Lexp -> list Lexp -> Prop :=

  | sig2hcc_init : forall B L A, L =mul= (A ⁺) :: [A ⁻] -> 0 |-cc B ; L
  | sig2hcc_one : forall B L, L =mul= [1] -> 0 |-cc B ; L 
  | sig2hcc_top : forall B L M, L =mul= Top :: M -> 0 |-cc B ; L
  | sig2hcc_bot : forall B L M n, L =mul= Bot :: M -> n |-cc B ; M -> S n |-cc B ; L
  | sig2hcc_par : forall B L M F G n, L =mul= (F $ G) :: M -> n |-cc B ; F :: G :: M -> S n |-cc B ; L 
  | sig2hcc_cut : forall B L M N F m n, 
      L =mul= (M ++ N)  ->
      m|-cc B ; F :: M ->
                n|-cc B ; F° :: N -> S (max n m)|-cc B ; L
  | sig2hcc_ccut : forall B L M N F m n, 
      L =mul= (M ++ N) ->
      m|-cc B ; (! F) :: M ->
                n|-cc F° :: B ; N -> S (max n m)|-cc B ; L 
  | sig2hcc_tensor : forall B L M N F G n m, 
      L =mul= (F ** G) :: (M ++ N)  ->
      m |-cc B ; F :: M ->
                 n |-cc B ; G :: N -> S (max n m) |-cc B ; L
  | sig2hcc_plus1: forall B L M F G n, L =mul= (F ⊕ G) :: M -> n |-cc B ; F :: M -> S n |-cc B ; L 
  | sig2hcc_plus2: forall B L M F G n, L =mul= (F ⊕ G) :: M -> n |-cc B ; G :: M -> S n |-cc B ; L 
  | sig2hcc_with: forall B L M F G n m, 
      L =mul= (F & G) :: M ->
      m |-cc B ; F :: M ->
                 n |-cc B ; G :: M -> S (max n m) |-cc B ; L
                                                             
  | sig2hcc_copy: forall B D L M F n, 
      D =mul= F :: B -> L =mul= F :: M ->
      n |-cc D ; L -> 
                 S n|-cc D ; M 

  | sig2hcc_quest : forall B L M F n, L =mul= (? F) :: M  ->
                                      n |-cc F :: B ; M -> 
                                                      S n |-cc B ; L
                                                                     
  | sig2hcc_bang : forall B F L n, L =mul= [! F] ->
                                   n |-cc  B ; [F] ->
                                               S n |-cc  B ; L
                                                               
  | sig2hcc_ex  : forall B L n FX M t,
      L =mul= E{FX} ::  M -> n |-cc B ; (Subst FX t) :: M -> S n |-cc  B ; L
  | sig2hcc_fx  : forall B L n FX M,  L =mul= (F{FX}) :: M -> (forall x, n |-cc B ; [Subst FX x] ++  M) -> S n |-cc B ; L
                                                                                                                          
  where "n |-cc B ; L" := (sig2hcc n B L).

  Lemma sig2hcc_der_compat : forall n (B1 B2 L1 L2 : list Lexp), B1 =mul= B2 -> L1 =mul= L2 -> n |-cc B1 ; L1 -> n |-cc B2 ; L2.
  Proof.
    intros n B1 B2 L1 L2 PB PL H.
    revert L1 L2 PL B1 B2 PB H;
      induction n using strongind; intros.
    - inversion H; subst. 
      +
        refine (sig2hcc_init _ (transitivity (symmetry PL) H0)). 
      +
        refine (sig2hcc_one _ (transitivity (symmetry PL) H0)).
      +
        refine (sig2hcc_top _ (transitivity (symmetry PL) H0)).
    - inversion H0; subst; try rewrite PL in H3; try rewrite PL in H2;
        try rewrite PB in H3; try rewrite PB in H2.
      +
        refine (sig2hcc_bot H2 _); auto.
        apply H with (L1:= M) (B1:=B1); auto.
      +
        refine (sig2hcc_par H2 _); auto.
        apply H with (L1:= F :: G :: M) (B1:=B1); auto.
      +
        refine (sig2hcc_cut H2 _ _).
        eapply H with (L1:= F :: M) (B1:=B1); auto.
        eapply H with (L1:= F° :: N) (B1:=B1); auto.
      +
        refine (sig2hcc_ccut H2 _ _).
        eapply H with (L1:= (! F) :: M) (B1:=B1); auto.
        eapply H with (L1:=N) (B1:= F° :: B1); auto.
      + 
        refine (sig2hcc_tensor H2 _ _).
        apply H with (L1:= F :: M) (B1:=B1); auto.
        apply H with (L1:= G :: N) (B1:=B1); auto.
      +
        refine (sig2hcc_plus1 H2 _).
        apply H with (L1:= F :: M) (B1:=B1); auto. 
      +
        refine (sig2hcc_plus2 H2 _).
        apply H with (L1:= G :: M) (B1:=B1); auto. 
      +
        refine (sig2hcc_with H2 _ _).
        apply H with (L1:= F :: M) (B1:=B1); auto.
        apply H with (L1:= G :: M) (B1:=B1); auto.
      + 
        refine (sig2hcc_copy H2 H3 _).   
        apply H with (L1:= L) (B1:=B1); auto. 
      +
        refine (sig2hcc_quest H2 _).
        apply H with (L1:= M) (B1:= F :: B1); auto. 
      +
        refine (sig2hcc_bang H2 _).
        apply H with (L1:= [F]) (B1:=B1); auto.
      + (* exists *)
        eapply sig2hcc_ex;eauto.
      + (* forall *)
        eapply sig2hcc_fx;eauto.    
  Qed. 
  
  Generalizable All Variables.
  Instance sig2hcc_der_morphism :
    Proper (meq ==> meq ==> iff) (sig2hcc n).
  Proof.
    unfold Proper; unfold respectful. 
    intros n B1 B2 PB L1 L2 PL.
    split; intro H.
    refine (sig2hcc_der_compat PB PL H).
    refine (sig2hcc_der_compat (symmetry PB) (symmetry PL) H).
  Qed.

  (** System with all the inductive measures needed for the proof of cut-elimination *)
  Reserved Notation " n '|~>' m ';' B ';' L" (at level 80).

  Inductive sig3: nat -> nat -> list Lexp -> list Lexp -> Prop := 
  | sig3_init : forall (B L: list Lexp) A, L =mul= (A ⁺) :: [A ⁻] -> 0 |~> 0 ; B ; L
  | sig3_one : forall (B L: list Lexp), L =mul= [1] -> 0 |~> 0 ; B ; L
  | sig3_top : forall (B L M: list Lexp), L =mul= Top :: M -> 0 |~> 0 ; B ; L
  | sig3_bot : forall (B L M: list Lexp) n c, L =mul= Bot :: M -> n |~> c ; B ; M -> S n |~> c ; B ; L
  | sig3_par : forall (B L M: list Lexp) F G n c, L =mul= (F $ G) :: M -> n |~> c ; B ; F :: G :: M -> S n |~> c ;B ; L
  | sig3_tensor : forall (B L M N: list Lexp) F G n m c1 c2, L =mul= (F ** G) :: (M ++ N) -> m |~> c1 ; B ; F :: M -> n |~> c2 ; B ; G :: N -> S (max n m)  |~> c1+c2 ;B ; L
  | sig3_plus1: forall (B L M: list Lexp) F G n c, L =mul= (F ⊕ G) :: M -> n |~> c ; B ; F :: M -> S n |~> c ; B ; L
  | sig3_plus2: forall (B L M: list Lexp) F G n c, L =mul= (F ⊕ G) :: M -> n |~> c ; B ; G :: M -> S n |~> c ; B ; L
  | sig3_with: forall (B L M: list Lexp) F G n m c1 c2, L =mul= (F & G) :: M -> m |~> c1 ; B ; F :: M ->
                                                                                               n |~> c2 ; B ; G :: M -> S (max n m) |~> c1 + c2; B ; L
  | sig3_copy: forall (B L M D: list Lexp) F n c, D =mul= F :: B -> L =mul= F :: M -> n |~> c; D ; L -> S n |~> c ; D ; M
  | sig3_quest : forall (B L M: list Lexp) F n c, L =mul= (? F) :: M  -> n |~> c; F :: B ; M -> S n |~> c; B ; L
  | sig3_bang : forall (B L: list Lexp) F n c, L =mul= [! F] -> n |~>  c; B ; [F] -> S n |~> c ; B ; L 
                                                                                                       
  | sig3_ex  : forall (B L: list Lexp) n c FX M t,
      L =mul= E{FX} ::  M -> n |~> c; B ; (Subst FX t) :: M -> S n |~> c; B ; L
  | sig3_fx  : forall (B L: list Lexp) n c FX M,  L =mul= (F{FX}) :: M -> (forall x, n |~> c; B ; (Subst FX x) ::  M) -> S n |~> c; B ; L
                                                                                                                                          

  | sig3_CUT : forall (B L: list Lexp) n c w h, sig3_cut_general w h n c B L -> S n |~> S c ; B ; L 

  with
  sig3_cut_general : nat -> nat -> nat -> nat -> list Lexp -> list Lexp -> Prop :=
  | sig3_cut : forall (B L M N: list Lexp) F m n c1 c2 w h, 
      w = Lexp_weight F ->
      h = m + n ->
      L =mul= (M ++ N) -> 
      m |~> c1 ; B ; F :: M -> 
                     n |~> c2 ; B ; F° :: N -> 
                                    sig3_cut_general w h (max n m) (c1 + c2) B L
  | sig3_ccut : forall (B L M N: list Lexp) F m n c1 c2 w h, 
      w = Lexp_weight (! F) ->
      h = m + n ->
      L =mul= (M ++ N) -> 
      m |~> c1 ; B ; (! F) :: M -> 
                     n |~> c2 ; F° :: B ; N -> 
                                          sig3_cut_general w h (max n m) (c1 + c2) B L
  where "n |~> m ; B ; L" := (sig3 n m B L).

  Notation " n '~>' m ';' w ';' h ';' B ';' L"
    := (sig3_cut_general w h n m B L) (at level 80).


  Lemma sig3_der_compat : forall n c (B1 B2 L1 L2: list Lexp), 
      B1 =mul= B2 -> L1 =mul= L2 -> n |~> c ; B1 ; L1 -> n |~> c ; B2 ; L2.
  Proof.
    intros n c B1 B2 L1 L2 PB PL H.
    revert dependent L1;
      revert dependent L2;
      revert dependent B1;
      revert dependent B2;
      revert dependent c; 
      induction n using strongind; intros.
    - inversion H; subst.
      refine (sig3_init _ (transitivity (symmetry PL) H0)). 
      refine (sig3_one _ (transitivity (symmetry PL) H0)).
      refine (sig3_top _ (transitivity (symmetry PL) H0)).

    - inversion H0; subst; try rewrite PL in H3; try rewrite PL in H2;
        try rewrite PB in H3; try rewrite PB in H2.
      +  
        refine (sig3_bot H2 _); auto.
        apply H with (L1:= M) (B1:=B1); auto.
      +
        refine (sig3_par H2 _); auto.
        apply H with (L1:= F :: G :: M) (B1:=B1); auto.
      +
        refine (sig3_tensor H2 _ _).
        apply H with (L1:= F :: M) (B1:=B1); auto.
        apply H with (L1:= G :: N) (B1:=B1); auto.
      +
        refine (sig3_plus1 H2 _). 
        apply H with (L1:= F :: M) (B1:=B1); auto.
      +
        refine (sig3_plus2 H2 _).
        apply H with (L1:= G :: M) (B1:=B1); auto.
      +
        refine (sig3_with H2 _ _).
        apply H with (L1:= F :: M) (B1:=B1); auto.
        apply H with (L1:= G :: M) (B1:=B1); auto.
      + 
        refine (sig3_copy H2 H3 _).
        apply H with (L1:= L) (B1:=B1); auto.    
      +
        refine (sig3_quest H2 _).
        apply H with (L1:= M) (B1:= F :: B1); auto. 
      +
        refine (sig3_bang H2 _).
        apply H with (L1:= [F]) (B1:=B1); auto. 
      + (* exists *)
        eapply sig3_ex;eauto.
      + (* forall *)
        eapply sig3_fx;eauto.
      + 
        inversion H2; subst.
        ++
          eapply sig3_CUT.
          eapply sig3_cut with (F:=F); [ auto | auto | | |].
          rewrite <- PL. exact H4.
          apply H with (L1:= F :: M) (B1:=B1); auto.
          apply H with (L1:= F° :: N) (B1:=B1); auto.
        ++
          eapply sig3_CUT.
          eapply sig3_ccut with (F:=F) (M:=M) (N:=N) ; [ auto | auto | | | ].
          rewrite <- PL. exact H4.
          eapply H with (L1:= (! F) :: M) (B1:=B1); auto.
          apply H with (L1:= N) (B1:= F° :: B1); auto.
  Qed.

  Generalizable All Variables.
  Instance sig3_der_morphism :
    Proper (meq ==> meq ==> iff) (sig3 n c).
  Proof.
    unfold Proper; unfold respectful. 
    intros n c B1 B2 PB L1 L2 PL.
    split; intro H.
    refine (sig3_der_compat PB PL H).
    refine (sig3_der_compat (symmetry PB) (symmetry PL) H).
  Qed.

  Hint Constructors sig2h.
  Hint Constructors sig2hc.
  Hint Constructors sig2hcc.
  Hint Constructors sig3.

  Theorem sig2hc_then_sig2hcc: forall n B L, sig2hc n B L -> sig2hcc n B L.
  Proof.
    intros.
    induction H.
    eapply sig2hcc_init; eassumption.
    eapply sig2hcc_one; eassumption.
    eapply sig2hcc_top; eassumption.
    eapply sig2hcc_bot; eassumption.
    eapply sig2hcc_par; eassumption.
    eapply sig2hcc_cut; eassumption.
    eapply sig2hcc_tensor; eassumption.
    eapply sig2hcc_plus1; eassumption.
    eapply sig2hcc_plus2; eassumption.
    eapply sig2hcc_with; eassumption.
    eapply sig2hcc_copy; eassumption.
    eapply sig2hcc_quest; eassumption.
    eapply sig2hcc_bang; eassumption.  
    eapply sig2hcc_ex; eassumption.  
    eapply sig2hcc_fx; eassumption.     
  Qed. 

  Axiom fx_swap_sig2h : forall M B FX,
      (forall x : Term, exists m : nat, m |-- B; [Subst FX x] ++ M) -> 
      (exists m : nat, forall x : Term, m |-- B; [Subst FX x] ++ M).
  
  Axiom fx_swap_sig2hc : forall M B FX,
      (forall x : Term, exists m : nat, m |-c B; [Subst FX x] ++ M) -> 
      (exists m : nat, forall x : Term, m |-c B; [Subst FX x] ++ M).

  Axiom fx_swap_sig2hcc : forall M B FX,
      (forall x : Term, exists m : nat, m |-cc B; [Subst FX x] ++ M) -> 
      (exists m : nat, forall x : Term, m |-cc B; [Subst FX x] ++ M).

  Axiom fx_swap_sig3h : forall c M B FX,
      (forall x : Term, exists m : nat, m |~> c ; B; [Subst FX x] ++ M) -> 
      (exists m : nat, forall x : Term, m |~> c ; B; [Subst FX x] ++ M).

  Axiom fx_swap_sig3c : forall m M B FX,
      (forall x : Term, exists c : nat, m |~> c ; B; [Subst FX x] ++ M) -> 
      (exists c : nat, forall x : Term, m |~> c ; B; [Subst FX x] ++ M).
  
  Theorem sig2hcc_then_sig2hc: forall n B L, sig2hcc n B L -> exists m, sig2hc m B L.
  Proof.
    intros.
    induction H; try destruct IHsig2hcc; try destruct IHsig2hcc1; try destruct IHsig2hcc2.

    eexists; eapply sig2hc_init; eassumption.
    eexists; eapply sig2hc_one; eassumption.
    eexists; eapply sig2hc_top; eassumption.
    eexists; eapply sig2hc_bot; eassumption.
    eexists; eapply sig2hc_par; eassumption.
    eexists; eapply sig2hc_cut; eassumption.
    eexists; eapply sig2hc_cut with (F:=!F) (M:=M) (N:=N) (m:=x); auto.
    eapply sig2hc_quest with (F:=F°); eauto.
    eexists; eapply sig2hc_tensor; eassumption.
    eexists; eapply sig2hc_plus1; eassumption.
    eexists; eapply sig2hc_plus2; eassumption.
    eexists; eapply sig2hc_with; eassumption.
    eexists; eapply sig2hc_copy; eassumption.
    eexists; eapply sig2hc_quest; eassumption.
    eexists; eapply sig2hc_bang; eassumption.  
    eexists; eapply sig2hc_ex; eassumption.  
    apply fx_swap_sig2hc in H1.  
    destruct H1.
    eexists.
    eapply sig2hc_fx; eauto. 
  Qed. 

  Theorem sig2hc_iff_sig2hcc: forall B L, (exists n, sig2hc n B L) <-> exists m, sig2hcc m B L.
  Proof.
    split; intros.
    *
      destruct H.
      eexists.
      apply sig2hc_then_sig2hcc; eauto.
    *
      destruct H.
      eapply sig2hcc_then_sig2hc; eauto.
  Qed.

  Theorem sig2hcc_then_sig3 :  forall B L n, 
      n |-cc B ; L -> exists c, n |~> c ; B ; L.
  Proof.
    intros.
    revert dependent B;
      revert dependent L.
    induction n using strongind; intros L B Hyp.
    **
      inversion Hyp; subst; eexists.
      eapply sig3_init; eassumption.
      eapply sig3_one; eassumption.
      eapply sig3_top; eassumption.
    **
      inversion Hyp; subst.
      ***
        assert (exists c : nat, n |~> c ; B; M) as Hn by solve [eapply H; auto].
        destruct Hn.
        eexists.
        refine (sig3_bot H1 H0).
      ***
        assert (exists c : nat, n |~> c ; B; F :: G :: M) as Hn by solve [eapply H; auto].
        destruct Hn.
        eexists.
        refine (sig3_par H1 H0).
      ***
        assert (exists c : nat, m |~> c ; B; F :: M) as Hn1 by solve [eapply H; auto].
        assert (exists c : nat, n0 |~> c ; B; F° :: N) as Hn2 by solve [eapply H; auto].      
        destruct Hn1, Hn2.
        eexists.
        eapply sig3_CUT.
        refine (sig3_cut _ _ _ H0 H4); auto.
      ***
        assert (exists c : nat, m |~> c ; B; (! F) :: M) as Hn1 by solve [eapply H; auto].
        assert (exists c : nat, n0 |~> c ; F° :: B; N) as Hn2 by solve [eapply H; auto].     
        destruct Hn1, Hn2.
        eexists.
        eapply sig3_CUT.
        refine (sig3_ccut _ _ _ H0 H4); auto.
      ***
        assert (exists c : nat, m |~> c ; B; F :: M) as Hn1 by solve [eapply H; auto].
        assert (exists c : nat, n0 |~> c ; B; G :: N) as Hn2 by solve [eapply H; auto].     
        destruct Hn1, Hn2.
        eexists.
        refine (sig3_tensor H1 H0 H4).
      ***                  
        assert (exists c : nat, n |~> c ; B; F :: M) as Hn by solve [eapply H; auto].
        destruct Hn.
        eexists.
        refine (sig3_plus1 H1 H0).
      ***                  
        assert (exists c : nat, n |~> c ; B; G :: M) as Hn by solve [eapply H; auto].
        destruct Hn.
        eexists.
        refine (sig3_plus2 H1 H0).                        
      ***
        assert (exists c : nat, m |~> c ; B; F :: M) as Hn1 by solve [eapply H; auto].
        assert (exists c : nat, n0 |~> c ; B; G :: M) as Hn2 by solve [eapply H; auto].      
        destruct Hn1, Hn2.
        eexists.
        refine (sig3_with H1 H0 H4).
      ***
        assert (exists c : nat, n |~> c ; B; L0) as Hn by solve [eapply H; auto].
        destruct Hn.
        eexists.
        rewrite H2 in H0.
        refine (sig3_copy H1 _ H0); auto.
      ***
        assert (exists c : nat, n |~> c ; F :: B; M) as Hn by solve [eapply H; auto].
        destruct Hn.
        eexists.
        refine (sig3_quest H1 H0).               
      ***
        assert (exists c : nat, n |~> c ; B; [F]) as Hn by solve [eapply H; auto].
        destruct Hn.
        eexists.
        refine (sig3_bang H1 H0).
      ***
        assert (exists c : nat, n |~> c ; B; Subst FX t :: M) as Hn by solve [eapply H; auto].
        destruct Hn.
        eexists.
        refine (sig3_ex H1 H0).
      ***
        assert (forall x, exists c : nat, n |~> c ; B; [Subst FX x] ++ M)
          as Hn by solve [intro; eapply H; auto].
        apply fx_swap_sig3c in Hn.
        destruct Hn.
        eexists.
        refine (sig3_fx H1 H0).
  Qed.        
  

  Theorem sig3_then_sig2hcc :  forall B L n c, 
      n |~> c ; B ; L  -> n |-cc B ; L.
  Proof.
    intros.
    revert dependent B;
      revert dependent L;
      revert dependent c.
    induction n using strongind; intros c L B Hyp.
    **
      inversion Hyp; subst.
      eapply sig2hcc_init; eassumption.
      eapply sig2hcc_one; eassumption.
      eapply sig2hcc_top; eassumption.
    **
      inversion Hyp; subst. 
      ***
        assert (n |-cc B; M) as Hc by
              solve [eapply H; auto; eassumption].
        refine (sig2hcc_bot H1 _); auto.
      ***
        assert (n |-cc B; F :: G :: M) as Hc by
              solve [eapply H; auto; eassumption].
        refine (sig2hcc_par H1 _); auto.
      ***
        assert (m |-cc B; F :: M) as Hc1 by
              solve [eapply H; auto; eassumption].
        assert (n0 |-cc B; G :: N) as Hc2 by
              solve [eapply H; auto; eassumption].        
        refine (sig2hcc_tensor H1 Hc1 Hc2).
      ***                  
        assert (n |-cc B; F :: M) as Hc by
              solve [eapply H; auto; eassumption].
        refine (sig2hcc_plus1 H1 Hc).
      ***                  
        assert (n |-cc B; G :: M) as Hc by
              solve [eapply H; auto; eassumption].
        refine (sig2hcc_plus2 H1 Hc).                        
      ***
        assert (m |-cc B; F :: M) as Hc1 by
              solve [eapply H; auto; eassumption].
        assert (n0 |-cc B; G :: M) as Hc2 by
              solve [eapply H; auto; eassumption].       
        refine (sig2hcc_with H1 Hc1 Hc2).
      ***
        assert (n |-cc B; L0) as Hc by
              solve [eapply H; auto; eassumption].
        refine (sig2hcc_copy H1 H2 Hc).
      ***
        assert (n |-cc F :: B; M) as Hc by
              solve [eapply H; auto; eassumption].
        refine (sig2hcc_quest H1 Hc).               
      ***
        assert (n |-cc B; [F]) as Hc by
              solve [eapply H; auto; eassumption].
        refine (sig2hcc_bang H1 Hc).
      ***
        assert (n |-cc B; Subst FX t :: M) as Hc by
              solve [eapply H; auto; eassumption].
        refine (sig2hcc_ex H1 Hc).
      ***
        assert (forall x, n |-cc B; [Subst FX x] ++ M)
          as Hc by solve [intro; eapply H; eauto].
        refine (sig2hcc_fx H1 Hc).
      ***
        inversion H1; subst. 
        assert (m |-cc B; F :: M) as Hc1 by
              solve [eapply H; auto; eassumption].
        assert (n0 |-cc B; F° :: N) as Hc2 by
              solve [eapply H; auto; eassumption]. 
        refine (sig2hcc_cut H3 Hc1 Hc2).

        assert (m |-cc B; (! F) :: M) as Hc1 by
              solve [eapply H; auto; eassumption].
        assert (n0 |-cc F° :: B; N) as Hc2 by
              solve [eapply H; auto; eassumption].        
        refine (sig2hcc_ccut _ Hc1 Hc2); auto.
  Qed.        

  Theorem sig3_iff_sig2hcc :  forall B L, 
      (exists n c, n |~> c ; B ; L) <-> exists m, m |-cc B ; L.
  Proof.
    split; intros.
    *
      do 2 destruct H.
      eexists.
      eapply sig3_then_sig2hcc; eauto.
    *
      destruct H.
      eexists.
      eapply sig2hcc_then_sig3; eauto.
  Qed.

  
  
End SqSystems.

