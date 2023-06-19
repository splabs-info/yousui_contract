# #!/bin/bash

# # sui client merge-coin --primary-coin 0x6667eca76b8d0c346f35624475c915b13f2f7223be64a081190b9568c50aeb64 --coin-to-merge 0x8148bcc5d9a75fb4d19506d15c3033aedc8f9ee8ba6113f352ebee166c60a48e --gas-budget 100000000

# # sui client split-coin --coin-id 0x490c11f4d8bad5ae95a9fc9e291fd709f6b9adc4e6dd6733f2fc7c7452655765 --amounts 1000000000000 --gas-budget 400000000

# # sui client upgrade --upgrade-capability 0x5f4aa21406914c454d77a1c1142a06791eaca5396eab947dbc5736a272d702be --gas-budget 400000000 --skip-dependency-verification

# # ------------------------------------------------ NOTE ------------------------------------------------------

# clock="0x6"

# gas="400000000"
# tx_hash="3ZojZnbG2XCZP1P78JQJLYRLUNnpzmhKb5u36eqhVEWk"

# package_base="0xf0c3f973bbec66e055b79d0bf1ce11d09a7e474fe34cca21e27790d3f7cd4907"
# package_upgarade="0xfa5729076fb51c973782698a06afe037db5d2ba165795d05efc26a028676bb7a"

# admin_storage="0x38b4941c66d7952e4309b7c0f59edf50bb7f76c7e4f50bec5a05427247f8e12e"
# project_storage="0xe731e109303cbed2f1ffc1706de6fe5ac2a63df6f846308dd74d8ab464708061"

# project="0x5c754b29202a843c30b8e77311233a6b9b4a4bec2bc65271d6d15dffd8566a0d"

# round_name_private="Private-Round"
# round_type_private="$package_base::launchpad_presale::Round"

# round_name_og="OG-Round-V3"
# round_type_og="$package_base::launchpad_presale::Round"

# round_name_public="Public-Round"
# round_type_public="$package_base::launchpad_ido::Round"

# sale_token_type="0xd0291b939fb336d7b0c9fcaaec6a708f673c98fbca077044b76e3a056aca81cc::txui::TXUI"
# sale_token_decimal="9"

# method_payment_type="0x2::sui::SUI"
# method_payment_decimal="9"



# # # ------------------------------------------------ PUBLISH ------------------------------------------------
# # PACKAGE_ID=`sui client publish --skip-dependency-verification --gas-budget ${GAS_CALL} | grep '\"packageId\": String(\"' | head -n 1 | awk -F ' ' '{print $2}' | cut -c 9-74`
# # echo "PackageId: ${PACKAGE_ID}"



# # # ------------------------------------------------ CREATE PROJECT ------------------------------------------------
# # sui client call --package $package_upgarade \
# # --module admin \
# # --function create_project \
# # --args $admin_storage $project_storage "SPLabs <> T-XUI" https://twitter.com/txui https://discord.com/txui https://t.me/txui https://medium.com/txui https://txui.io https://kts3.s3.ap-northeast-1.amazonaws.com/T-XUI.png "T-XUI is a token of Meta version. It has no intrinsic value or expectation of financial return. There is no official team or roadmap." https://project.yousui.io/txui \
# # --gas-budget $gas


# # # ============================================================================================ private round ============================================================================================
# # # ------------------------------------------------ CREATE FCFS ROUND (private round) ------------------------------------------------

# #     # public entry fun create_round_prasale<TOKEN>(
# #     #     admin_storage: &AdminStorage,
# #     #     clock: &Clock,
# #     #     project: &mut Project,
# #     #     name: String,
# #     #     token_decimal: u8,
# #     #     start_at: u64,
# #     #     end_at: u64,
# #     #     min_purchase: u64,
# #     #     max_purchase: u64,
# #     #     total_supply: u64,
# #     #     ctx: &mut TxContext
# #     # ) {

# # start_at="1686290400000" #13h d9
# # end_at="1686376800000" #13h d10

# # min_purchase="800000000000" #800
# # max_purchase="12000000000000" #12,000

# # total_supply="12000000000000" #12,000

# # sui client call --package $package_upgarade \
# # --module admin \
# # --function create_round_prasale \
# # --type-args $sale_token_type \
# # --args $admin_storage $clock $project $round_name_private $sale_token_decimal $start_at $end_at $min_purchase $max_purchase $total_supply \
# # --gas-budget $gas



# # # ------------------------------------------------ CREATE VESTING (private round) ------------------------------------------------

# #     # public entry fun create_vesting<ROUND>(
# #     #     admin_storage: &AdminStorage,
# #     #     clock: &Clock,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     tge_time: u64,
# #     #     tge_unlock_percent: u64,
# #     #     number_of_cliff_months: u64,
# #     #     number_of_linear_month: u64,
# #     #     ctx: &mut TxContext
# #     # ) {

# # tge_time="1686373200000"
# # tge_unlock_percent="30000000000"
# # number_of_cliff_months="0"
# # number_of_linear_month="7"

# # sui client call \
# # --package $package_upgarade \
# # --module admin \
# # --function create_vesting \
# # --type-args $round_type_private \
# # --args $admin_storage $clock $project $round_name_private $tge_time $tge_unlock_percent $number_of_cliff_months $number_of_linear_month \
# # --gas-budget $gas



# # # ------------------------------------------------ SET PAYMENT (private round) ------------------------------------------------

# #     # public entry fun add_payment<ROUND, PAYMENT>(
# #     #     admin_storage: &AdminStorage,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     ratio_per_token: u64,
# #     #     ratio_decimal: u8, // should 9
# #     #     payment_decimal: u8,
# #     #     ctx: &mut TxContext
# #     # ) {

# # ratio_per_token="125000"
# # ratio_decimal="9"

# # sui client call --package $package_upgarade \
# # --module admin \
# # --function add_payment \
# # --type-args $round_type_private $method_payment_type \
# # --args $admin_storage $project $round_name_private $ratio_per_token $ratio_decimal $method_payment_decimal \
# # --gas-budget $gas



# # # ------------------------------------------------ DEPOSIT BALANCE (private round) ------------------------------------------------

# # coin_id="0x065d96b0a5f14776e9bc4c7f4cf1fee479ae91f0e5f3cdf3ac94832082ec6c04"

# # sui client call --package $package_upgarade \
# # --module launchpad_presale \
# # --function deposit_balance \
# # --type-args $sale_token_type \
# # --args $project $round_name_private $coin_id \
# # --gas-budget $gas



# # # # ------------------------------------------------ USE AFFILIATE (private round) ------------------------------------------------

# #     # public entry fun use_affiliate_for_project<ROUND>(
# #     #     admin_storage: &AdminStorage,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     ctx: &mut TxContext
# #     # ) {

# # sui client call --package $package_upgarade \
# # --module admin \
# # --function use_affiliate_for_project \
# # --type-args $round_type_private \
# # --args $admin_storage $project $round_name_private \
# # --gas-budget $gas



# # # # # ------------------------------------------------ ADD COMMISSION (private round) ------------------------------------------------

# #     # public entry fun add_commission_list(
# #     #     admin_storage: &AdminStorage,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     milestones: vector<u64>,
# #     #     percents: vector<u64>,
# #     #     ctx: &mut TxContext
# #     # ) {

# # milestones='[3000000000000,9000000000000,12000000000000]' #[3000,9000,12000]
# # percents='[5000000000,13000000000,20000000000]' #[5%,13%,20%]

# # sui client call --package $package_upgarade \
# # --module admin \
# # --function add_commission_list \
# # --args $admin_storage $project $round_name_private $milestones $percents \
# # --gas-budget $gas



# # # # # ------------------------------------------------ REMOVE COMMISSION (private round) ------------------------------------------------

# #     # public entry fun remove_commission_list(
# #     #     admin_storage: &AdminStorage,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     milestones: vector<u64>,
# #     #     ctx: &mut TxContext
# #     # ) {

# # milestones='[13000000000000]'

# # sui client call --package $package_upgarade \
# # --module admin \
# # --function remove_commission_list \
# # --args $admin_storage $project $round_name_private $milestones \
# # --gas-budget $gas



# # # # # # ------------------------------------------------ ADD AFFILIATE (private round) ------------------------------------------------

# #     # public entry fun add_affiliator_list(
# #     #     admin_storage: &AdminStorage,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     affiliators: vector<address>,
# #     #     nations: vector<String>,
# #     #     ctx: &mut TxContext
# #     # ) {

# # affiliators='["0x1e41203958a8e97930e2a0d5f4de570cbd4d9fb9293b5e2f347662356ec57ea1","0x0078254df53e7d62b05a590f0fbff890213c5a660e1752c4315b513d6186f9b3","0xbb47b7e40f8e1f7f4cd6f15bdeceaccb2afcc103396fc70456dbc2b63f647679","0xd109607b4e1e698b8879ddcbbff0597251f5e70724c96baec12af2da6f321fa4","0x3a6a33bc7d2ebccd33b1dfc0b8a179f1656efe93a00dda91d8237dae30600758","0x87bce7d010ae8a4824ba9bc7445e831afdaaca4c858d610ccd4232bd566fbf66","0x0529e940a97d07c9d78ddba72607012cbff75e3c6d789a7be446e1fa8b760278"]'
# # nations='["AF","CN","VN","KR","VN","JP","FR"]'

# # sui client call --package $package_upgarade \
# # --module admin \
# # --function add_affiliator_list \
# # --args $admin_storage $project $round_name_private $affiliators $nations \
# # --gas-budget $gas



# # # # # # # ------------------------------------------------ REMOVE AFFILIATE (private round) ------------------------------------------------

# #     # public entry fun remove_affiliator_list(
# #     #     admin_storage: &AdminStorage,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     affiliators: vector<address>,
# #     #     nations: vector<String>,
# #     #     ctx: &mut TxContext
# #     # ) {


# # affiliators='["0xbb47b7e40f8e1f7f4cd6f15bdeceaccb2afcc103396fc70456dbc2b63f647679"]'
# # nations='["VN"]'

# # sui client call --package $package_upgarade \
# # --module admin \
# # --function remove_affiliator_list \
# # --args $admin_storage $project $round_name_private $affiliators $nations \
# # --gas-budget $gas



# # # # ------------------------------------------------ PURCHASE (private round) ------------------------------------------------

# # sale_token_amount="800000000000"
# # vec_payment='["0x6667eca76b8d0c346f35624475c915b13f2f7223be64a081190b9568c50aeb64"]'

# # affiliate_code="CN90213c5a660e1752c4315b513d6186f9b3"

# # sui client call --package $package_upgarade \
# # --module launchpad_presale \
# # --function purchase_without_nft \
# # --type-args $sale_token_type $method_payment_type \
# # --args $clock $project $round_name_private $vec_payment $sale_token_amount $affiliate_code \
# # --gas-budget $gas


# # # # # ============================================================================================ OG round ============================================================================================
# # # # ------------------------------------------------ CREATE FCFS ROUND (og round) ------------------------------------------------

# #     # public entry fun create_round_prasale<TOKEN>(
# #     #     admin_storage: &AdminStorage,
# #     #     clock: &Clock,
# #     #     project: &mut Project,
# #     #     name: String,
# #     #     token_decimal: u8,
# #     #     start_at: u64,
# #     #     end_at: u64,
# #     #     min_purchase: u64,
# #     #     max_purchase: u64,
# #     #     total_supply: u64,
# #     #     ctx: &mut TxContext
# #     # ) {

# # start_at="1686640334000" #13h d9
# # end_at="1686648600000" #13h d10

# # min_purchase="100000000000" #100
# # max_purchase="1000000000000" #1,000

# # total_supply="1000000000000" #1,000

# # sui client call --package $package_upgarade \
# # --module admin \
# # --function create_round_prasale \
# # --type-args $sale_token_type \
# # --args $admin_storage $clock $project $round_name_og $sale_token_decimal $start_at $end_at $min_purchase $max_purchase $total_supply \
# # --gas-budget $gas



# # # # ------------------------------------------------ CREATE VESTING (og round) ------------------------------------------------

# #     # public entry fun create_vesting<ROUND>(
# #     #     admin_storage: &AdminStorage,
# #     #     clock: &Clock,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     tge_time: u64,
# #     #     tge_unlock_percent: u64,
# #     #     number_of_cliff_months: u64,
# #     #     number_of_linear_month: u64,
# #     #     ctx: &mut TxContext
# #     # ) {

# # tge_time="1686648600000"
# # tge_unlock_percent="20000000000"
# # number_of_cliff_months="3"
# # number_of_linear_month="5"

# # sui client call \
# # --package $package_upgarade \
# # --module admin \
# # --function create_vesting \
# # --type-args $round_type_og \
# # --args $admin_storage $clock $project $round_name_og $tge_time $tge_unlock_percent $number_of_cliff_months $number_of_linear_month \
# # --gas-budget $gas



# # # ------------------------------------------------ SET PAYMENT (og round) ------------------------------------------------

# #     # public entry fun add_payment<ROUND, PAYMENT>(
# #     #     admin_storage: &AdminStorage,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     ratio_per_token: u64,
# #     #     ratio_decimal: u8, // should 9
# #     #     payment_decimal: u8,
# #     #     ctx: &mut TxContext
# #     # ) {

# # ratio_per_token="240000"
# # ratio_decimal="9"

# # sui client call --package $package_upgarade \
# # --module admin \
# # --function add_payment \
# # --type-args $round_type_og $method_payment_type \
# # --args $admin_storage $project $round_name_og $ratio_per_token $ratio_decimal $method_payment_decimal \
# # --gas-budget $gas



# # # ------------------------------------------------ DEPOSIT BALANCE (og round) ------------------------------------------------

# # coin_id="0x2990ec1efaa035f0f980b91543b21abf2c3c18538cd2e5255010526f1c2d9a41"

# # sui client call --package $package_upgarade \
# # --module launchpad_presale \
# # --function deposit_balance \
# # --type-args $sale_token_type \
# # --args $project $round_name_og $coin_id \
# # --gas-budget $gas



# # # # ------------------------------------------------ SET WHITELIST (og round) ------------------------------------------------

# #     # public entry fun set_whitelist<ROUND>(
# #     #     admin_storage: &AdminStorage,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     investors: vector<address>,
# #     #     ctx: &mut TxContext
# #     # ) {

# # # investors='["0x1e41203958a8e97930e2a0d5f4de570cbd4d9fb9293b5e2f347662356ec57ea1","0x0078254df53e7d62b05a590f0fbff890213c5a660e1752c4315b513d6186f9b3","0xbb47b7e40f8e1f7f4cd6f15bdeceaccb2afcc103396fc70456dbc2b63f647679","0xd109607b4e1e698b8879ddcbbff0597251f5e70724c96baec12af2da6f321fa4","0x3a6a33bc7d2ebccd33b1dfc0b8a179f1656efe93a00dda91d8237dae30600758","0x87bce7d010ae8a4824ba9bc7445e831afdaaca4c858d610ccd4232bd566fbf66","0x0529e940a97d07c9d78ddba72607012cbff75e3c6d789a7be446e1fa8b760278"]'
# # investors='["0x1e41203958a8e97930e2a0d5f4de570cbd4d9fb9293b5e2f347662356ec57ea1"]'

# # sui client call --package $package_upgarade \
# # --module admin \
# # --function set_whitelist \
# # --type-args $round_type_og \
# # --args $admin_storage $project $round_name_og $investors \
# # --gas-budget $gas



# # # # ------------------------------------------------ REMOVE WHITELIST (og round) ------------------------------------------------

# # #    public entry fun remove_whitelist(
# # #         admin_storage: &AdminStorage,
# # #         project: &mut Project,
# # #         round_name: String,
# # #         investors: vector<address>,
# # #         ctx: &mut TxContext
# # #     ) {

# # investors='["0xa3853aef46411d68ee4ec6bad0a43219839a6d29e6761d008cb11e3032269d80"]'

# # sui client call --package $package_upgarade \
# # --module admin \
# # --function remove_whitelist \
# # --args $admin_storage $project $round_name_og $investors \
# # --gas-budget $gas



# # # # ------------------------------------------------ SET USE NFT PURCHASE (og round) ------------------------------------------------

# #     # public entry fun set_whitelist<ROUND>(
# #     #     admin_storage: &AdminStorage,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     investors: vector<address>,
# #     #     ctx: &mut TxContext
# #     # ) {

# # is_use_nft_purchase="true"

# # sui client call --package $package_upgarade \
# # --module admin \
# # --function set_use_nft_purchase \
# # --type-args $round_type_og \
# # --args $admin_storage $project $round_name_og $is_use_nft_purchase \
# # --gas-budget $gas

# # # # ------------------------------------------------ SET set_end_at (og round) ------------------------------------------------



# #     # public entry fun set_end_at<ROUND>(
# #     #     admin_storage: &AdminStorage,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     new_end_at: u64,
# #     #     ctx: &mut TxContext
# #     # ) {

# # new_end_at="1686567600000"

# # sui client call --package $package_upgarade \
# # --module admin \
# # --function set_end_at \
# # --type-args $round_type_og \
# # --args $admin_storage $project $round_name_og $new_end_at \
# # --gas-budget $gas



# # # # # ------------------------------------------------ SET set_total_supply (og round) ------------------------------------------------


# #     # public entry fun set_total_supply<ROUND>(
# #     #     admin_storage: &AdminStorage,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     new_total_supply: u64,
# #     #     ctx: &mut TxContext
# #     # ) {

# # new_total_supply="1200000000000"

# # sui client call --package $package_upgarade \
# # --module admin \
# # --function set_total_supply \
# # --type-args $round_type_og \
# # --args $admin_storage $project $round_name_og $new_total_supply \
# # --gas-budget $gas



# # # # # ------------------------------------------------ SET set_is_open_claim_vesting (og round) ------------------------------------------------



#     # public entry fun set_is_open_claim_vesting<ROUND>(
#     #     admin_storage: &AdminStorage,
#     #     project: &mut Project,
#     #     round_name: String,
#     #     new_is_open_claim_vesting: bool,
#     #     ctx: &mut TxContext
#     # ) {

# new_is_open_claim_vesting="true"

# sui client call --package $package_upgarade \
# --module admin \
# --function set_is_open_claim_vesting \
# --type-args $round_type_og \
# --args $admin_storage $project $round_name_og $new_is_open_claim_vesting \
# --gas-budget $gas




# # # # ------------------------------------------------ PURCHASE (og round) ------------------------------------------------

# # sale_token_amount="200000000000"
# # vec_payment='["0x6667eca76b8d0c346f35624475c915b13f2f7223be64a081190b9568c50aeb64"]'

# # affiliate_code="''"

# # sui client call --package $package_upgarade \
# # --module launchpad_presale \
# # --function purchase_without_nft \
# # --type-args $sale_token_type $method_payment_type \
# # --args $clock $project $round_name_og $vec_payment $sale_token_amount $affiliate_code \
# # --gas-budget $gas


# # sale_token_amount="100000000000"
# # vec_payment='["0x6667eca76b8d0c346f35624475c915b13f2f7223be64a081190b9568c50aeb64"]'

# # affiliate_code="''"
# # nft_purchase="0x26c9da4cbb9702bf57b7737d14eee4aa95d3577925fa2a8ba7aa8157c8a1bbca"

# # sui client call --package $package_upgarade \
# # --module launchpad_presale \
# # --function purchase \
# # --type-args $sale_token_type $method_payment_type \
# # --args $clock $project $round_name_og $vec_payment $sale_token_amount $affiliate_code $nft_purchase \
# # --gas-budget $gas




# # # ============================================================================================ public round ============================================================================================

# # # # # ------------------------------------------------ CREATE IDO ROUND (public round) ------------------------------------------------

# #     # public entry fun create_round_ido<TOKEN>(
# #     #     admin_storage: &AdminStorage,
# #     #     clock: &Clock,
# #     #     project: &mut Project,
# #     #     name: String,
# #     #     token_decimal: u8,
# #     #     start_at: u64,
# #     #     end_at: u64,
# #     #     // max_allocation: u64,
# #     #     // min_allocation: u64,
# #     #     min_purchase: u64,
# #     #     total_supply: u64,
# #     #     ctx: &mut TxContext

# # start_at="1686290400000"
# # end_at="1686376800000"
# # min_purchase="100000000000"
# # total_supply="2000000000000"

# # sui client call --package $package_upgarade \
# # --module admin \
# # --function create_round_ido \
# # --type-args $sale_token_type \
# # --args $admin_storage $clock $project $round_name_public $sale_token_decimal $start_at $end_at $min_purchase $total_supply \
# # --gas-budget $gas



# # # ------------------------------------------------ CREATE VESTING (public round) ------------------------------------------------

# #     # public entry fun create_vesting<ROUND>(
# #     #     admin_storage: &AdminStorage,
# #     #     clock: &Clock,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     tge_time: u64,
# #     #     tge_unlock_percent: u64,
# #     #     number_of_cliff_months: u64,
# #     #     number_of_linear_month: u64,
# #     #     ctx: &mut TxContext
# #     # ) {

# # tge_time="1686373200000"
# # tge_unlock_percent="20000000000"
# # number_of_cliff_months="0"
# # number_of_linear_month="10"

# # sui client call \
# # --package $package_upgarade \
# # --module admin \
# # --function create_vesting \
# # --type-args $round_type_public \
# # --args $admin_storage $clock $project $round_name_public $tge_time $tge_unlock_percent $number_of_cliff_months $number_of_linear_month \
# # --gas-budget $gas



# # # ------------------------------------------------ SET PAYMENT (public round) ------------------------------------------------

# #     # public entry fun add_payment<ROUND, PAYMENT>(
# #     #     admin_storage: &AdminStorage,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     ratio_per_token: u64,
# #     #     ratio_decimal: u8, // should 9
# #     #     payment_decimal: u8,
# #     #     ctx: &mut TxContext
# #     # ) {

# # ratio_per_token="250000"
# # ratio_decimal="9"

# # sui client call --package $package_upgarade \
# # --module admin \
# # --function add_payment \
# # --type-args $round_type_public $method_payment_type \
# # --args $admin_storage $project $round_name_public $ratio_per_token $ratio_decimal $method_payment_decimal \
# # --gas-budget $gas



# # # ------------------------------------------------ DEPOSIT BALANCE (public round) ------------------------------------------------

# # coin_id="0xa4c58d284f1b441cc0d8effa9e249d11e73f1a52690e1016bd005418a178053b"

# # sui client call --package $package_upgarade \
# # --module launchpad_ido \
# # --function deposit_balance \
# # --type-args $sale_token_type \
# # --args $project $round_name_public $coin_id \
# # --gas-budget $gas


# # # # ------------------------------------------------ PURCHASE (public round) ------------------------------------------------

# # sale_token_amount="200000000000"
# # vec_payment='["0x6667eca76b8d0c346f35624475c915b13f2f7223be64a081190b9568c50aeb64"]'

# # # public entry fun purchase<TOKEN, PAYMENT>(clock: &Clock, project: &mut Project, round_name: String, payment: vector<Coin<PAYMENT>>, token_amount: u64, ctx: &mut TxContext) {

# # sui client call --package $package_upgarade \
# # --module launchpad_ido \
# # --function purchase \
# # --type-args $sale_token_type $method_payment_type \
# # --args $clock $project $round_name_public $vec_payment $sale_token_amount \
# # --gas-budget $gas




# # # # ------------------------------------------------ CLAIM REFUND BANLANCE (public round) ------------------------------------------------

# # # public entry fun claim_refund_payment_coin<PAYMENT>(clock: &Clock, project: &mut Project, round_name: String, ctx: &mut TxContext) {

# # sui client call --package $package_upgarade \
# # --module launchpad_ido \
# # --function claim_refund_payment_coin \
# # --type-args $method_payment_type \
# # --args $clock $project $round_name_public \
# # --gas-budget $gas



# # # # ------------------------------------------------ SET set_end_at ------------------------------------------------



# #     # public entry fun set_end_at<ROUND>(
# #     #     admin_storage: &AdminStorage,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     new_end_at: u64,
# #     #     ctx: &mut TxContext
# #     # ) {

# # new_end_at="1686567600000"

# # sui client call --package $package_upgarade \
# # --module admin \
# # --function set_end_at \
# # --type-args $round_type_public \
# # --args $admin_storage $project $round_name_public $new_end_at \
# # --gas-budget $gas



# # # # ------------------------------------------------ SET set_is_open_claim_refund ------------------------------------------------



# #     # public entry fun set_is_open_claim_refund<ROUND>(
# #     #     admin_storage: &AdminStorage,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     new_is_open_claim_refund: bool,
# #     #     ctx: &mut TxContext
# #     # ) {

# # new_is_open_claim_refund="true"

# # sui client call --package $package_upgarade \
# # --module admin \
# # --function set_is_open_claim_refund \
# # --type-args $round_type_public \
# # --args $admin_storage $project $round_name_public $new_is_open_claim_refund \
# # --gas-budget $gas


# # # # # # ------------------------------------------------ SET set_is_open_claim_vesting (og round) ------------------------------------------------



# #     # public entry fun set_is_open_claim_vesting<ROUND>(
# #     #     admin_storage: &AdminStorage,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     new_is_open_claim_vesting: bool,
# #     #     ctx: &mut TxContext
# #     # ) {

# # new_is_open_claim_vesting="true"

# # sui client call --package $package_upgarade \
# # --module admin \
# # --function set_is_open_claim_vesting \
# # --type-args $round_type_public \
# # --args $admin_storage $project $round_name_public $new_is_open_claim_vesting \
# # --gas-budget $gas









# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 




















# # PROJECT="0x4d9e5356cf10c8dadce2c4609a1341f151685b1b92481737661a92d89637c053"
# # NAME="Private-sale"
# # # NAME="PUBLIC_ROUND"
# # CLOCK="0x6"
# # TOKEN_TYPE="0xd0291b939fb336d7b0c9fcaaec6a708f673c98fbca077044b76e3a056aca81cc::txui::TXUI"
# # PAYMENT_TYPE="0x2::sui::SUI"

# # ROUND="0x69024070a4f198de025f5c30226d5fc6b467bf4fb571ef91210d0763e0b2969e::launchpad_presale::Round"
# # ROUND="0xd0291b939fb336d7b0c9fcaaec6a708f673c98fbca077044b76e3a056aca81cc::launchpad_ido::Round"

# # CLIENT_ADDRESS=$(sui client addresses | tail -n +2)

# # SENDER=`echo ${CLIENT_ADDRESS} | cut -c 1-66 | head -n 1`
# # echo "Sender: ${SENDER}"

# # GAS_CALL=`sui client gas | sed -n 3p | awk -F ' | ' '{print $5}'`
# # echo "Data: ${GAS_CALL}"





# # #================================// CREATE PROJECT //==============================
# # DATA=`sui client call --package ${PACKAGE} \
# # --module admin \
# # --function create_project \
# # --args $ADMIN_STORAGE $PROJECT_STORAGE "T-XUI Project" https://twitter.com/txui https://discord.com/txui https://t.me/txui https://medium.com/txui https://txui.io https://kts3.s3.ap-northeast-1.amazonaws.com/T-XUI.png "T-XUI is a token of Meta version. It has no intrinsic value or expectation of financial return. There is no official team or roadmap." https://project.yousui.io/txui \
# # --gas-budget $GAS_CALL`
# # echo "Data: ${DATA}"


# # # ================================// CREATE PRESALE //==============================

# #     # public entry fun create_round_prasale<TOKEN>(
# #     #     admin_storage: &AdminStorage,
# #     #     clock: &Clock,
# #     #     project: &mut Project,
# #     #     name: String,
# #     #     token_decimal: u8,
# #     #     start_at: u64,
# #     #     end_at: u64,
# #     #     max_allocation: u64,
# #     #     min_allocation: u64,
# #     #     min_purchase: u64,
# #     #     total_supply: u64,
# #     #     ctx: &mut TxContext
# #     # ) {

# # TOKEN_DECIMAL="9"
# # START_AT="1686112800000"
# # END_AT="1686126600000"
# # MIN_ALLOCATION="12000000000"
# # MAX_ALLOCATION="100000000000"
# # MIN_PURCHASE="1500000000"
# # TOTAL_SUPPLY="500000000000"

# # DATA=`sui client call --package $PACKAGE \
# # --module admin \
# # --function create_round_prasale \
# # --type-args $TOKEN_TYPE \
# # --args $ADMIN_STORAGE $CLOCK $PROJECT $NAME $TOKEN_DECIMAL $START_AT $END_AT $MAX_ALLOCATION $MIN_ALLOCATION $MIN_PURCHASE $TOTAL_SUPPLY \
# # --gas-budget ${GAS_CALL}`
# # echo "Data: ${DATA}"


# # # ================================// CREATE VESTING //==============================


# #     # public entry fun create_vesting<ROUND>(
# #     #     admin_storage: &AdminStorage,
# #     #     clock: &Clock,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     tge_time: u64,
# #     #     tge_unlock_percent: u64,
# #     #     number_of_cliff_months: u64,
# #     #     number_of_linear_month: u64,
# #     #     ctx: &mut TxContext
# #     # ) {

# # TGE_TIME="1686124800000"
# # TGE_UNLOCK_PERCENT="30000000000"
# # CLIFF_MONTHS="0"
# # LINEAR_MONTHS="7"

# # DATA=`sui client call \
# # --package ${PACKAGE} \
# # --module admin \
# # --function create_vesting \
# # --type-args $ROUND \
# # --args $ADMIN_STORAGE $CLOCK $PROJECT $NAME $TGE_TIME $TGE_UNLOCK_PERCENT $CLIFF_MONTHS $LINEAR_MONTHS \
# # --gas-budget $GAS_CALL`
# # echo "Data: ${DATA}"


# # # # ================================// SET PAYMENT //==============================


# #     # public entry fun add_payment<ROUND, PAYMENT>(
# #     #     admin_storage: &AdminStorage,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     ratio_per_token: u64,
# #     #     ratio_decimal: u8, // should 9
# #     #     payment_decimal: u8,
# #     #     ctx: &mut TxContext
# #     # ) {

# # RATIO_PER_TOKEN="12500000"
# # RATIO_DECIMAL="9"
# # PAYMENT_DECIMAL="9"

# # DATA=`sui client call --package $PACKAGE \
# # --module admin \
# # --function add_payment \
# # --type-args $ROUND $PAYMENT_TYPE \
# # --args $ADMIN_STORAGE $PROJECT $NAME $RATIO_PER_TOKEN $RATIO_DECIMAL $PAYMENT_DECIMAL \
# # --gas-budget ${GAS_CALL}`
# # echo "Data: ${DATA}"

# # # # # ================================// DEPOSIT BALANCE //==============================


# # COIN="0xd8fdaeca9907d239ce4d2bfcf444a32db4bda61f17cbef1b054ee105a0d49b8d"

# # DATA=`sui client call --package $PACKAGE \
# # --module launchpad_presale \
# # --function deposit_balance \
# # --type-args $TOKEN_TYPE \
# # --args $PROJECT $NAME $COIN \
# # --gas-budget ${GAS_CALL}`
# # echo "Data: ${DATA}"

# # # ================================// SPLIT COIN //==============================

# # sui client split-coin --coin-id 0x35b37a08e1bce7b5139e5d81d1dc1705bdaa3e5e70a3359bdc8dd18a63bbb153 --amounts 5000000000000 --gas-budget 100000000

# # sui client split-coin --coin-id 0x490c11f4d8bad5ae95a9fc9e291fd709f6b9adc4e6dd6733f2fc7c7452655765 --amounts 500000000000 --gas-budget 100000000

# # sui client upgrade --upgrade-capability 0x5f4aa21406914c454d77a1c1142a06791eaca5396eab947dbc5736a272d702be --gas-budget 400000000 --skip-dependency-verification


# # # # # ================================// SET IS_ONCE_PURCHASE //==============================

# # # GAS_CALL=`sui client gas | sed -n 3p | awk -F ' | ' '{print $5}'`
# # # echo "Data: ${GAS_CALL}"

# #     # public entry fun set_use_once_purchase<ROUND>(
# #     #     admin_storage: &AdminStorage,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     is_once_purchase: bool,
# #     #     ctx: &mut TxContext
# #     # ) {

# # IS_ONCE_PURCHASE="true"

# # DATA=`sui client call --package $PACKAGE \
# # --module admin \
# # --function set_use_once_purchase \
# # --type-args $ROUND \
# # --args $ADMIN_STORAGE $PROJECT $NAME $IS_ONCE_PURCHASE \
# # --gas-budget ${GAS_CALL}`
# # echo "Data: ${DATA}"


# # # # # ================================// SET WHITELIST //==============================

# #     # public entry fun set_whitelist<ROUND>(
# #     #     admin_storage: &AdminStorage,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     investors: vector<address>,
# #     #     ctx: &mut TxContext
# #     # ) {

# # INVESTORS='["0x1e41203958a8e97930e2a0d5f4de570cbd4d9fb9293b5e2f347662356ec57ea1","0x0078254df53e7d62b05a590f0fbff890213c5a660e1752c4315b513d6186f9b3","0xbb47b7e40f8e1f7f4cd6f15bdeceaccb2afcc103396fc70456dbc2b63f647679","0xd109607b4e1e698b8879ddcbbff0597251f5e70724c96baec12af2da6f321fa4","0x3a6a33bc7d2ebccd33b1dfc0b8a179f1656efe93a00dda91d8237dae30600758","0x87bce7d010ae8a4824ba9bc7445e831afdaaca4c858d610ccd4232bd566fbf66","0x0529e940a97d07c9d78ddba72607012cbff75e3c6d789a7be446e1fa8b760278"]'
# # DATA=`sui client call --package $PACKAGE \
# # --module admin \
# # --function set_whitelist \
# # --type-args $ROUND \
# # --args $ADMIN_STORAGE $PROJECT $NAME $INVESTORS \
# # --gas-budget ${GAS_CALL}`
# # echo "Data: ${DATA}"


# # # # # # ================================// USE AFFILIATE //==============================

# #     # public entry fun use_affiliate_for_project<ROUND>(
# #     #     admin_storage: &AdminStorage,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     ctx: &mut TxContext
# #     # ) {

# # DATA=`sui client call --package $PACKAGE \
# # --module admin \
# # --function use_affiliate_for_project \
# # --type-args $ROUND \
# # --args $ADMIN_STORAGE $PROJECT $NAME \
# # --gas-budget ${GAS_CALL}`
# # echo "Data: ${DATA}"

# # # # # ================================// ADD COMMISSION //==============================

# #     # public entry fun add_commission_list(
# #     #     admin_storage: &AdminStorage,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     milestones: vector<u64>,
# #     #     percents: vector<u64>,
# #     #     ctx: &mut TxContext
# #     # ) {
# # milestones='[250000000,625000000,1250000000,2500000000]'
# # percents='[3000000000,7000000000,15000000000,30000000000]'
# # DATA=`sui client call --package $PACKAGE \
# # --module admin \
# # --function add_commission_list \
# # --args $ADMIN_STORAGE $PROJECT $NAME $milestones $percents \
# # --gas-budget ${GAS_CALL}`
# # echo "Data: ${DATA}"


# # # # # # # ================================// REMOVE COMMISSION //==============================

# # #     # public entry fun remove_commission_list(
# # #     #     admin_storage: &AdminStorage,
# # #     #     project: &mut Project,
# # #     #     round_name: String,
# # #     #     milestones: vector<u64>,
# # #     #     ctx: &mut TxContext
# # #     # ) {
# # # milestones='[10000000000,3000000000,1500000000]'
# # # DATA=`sui client call --package $PACKAGE \
# # # --module admin \
# # # --function remove_commission_list \
# # # --args $ADMIN_STORAGE $PROJECT $NAME $milestones \
# # # --gas-budget ${GAS_CALL}`
# # # echo "Data: ${DATA}"

# # # # # ================================// ADD AFFILIATE //==============================

# #     # public entry fun add_affiliator_list(
# #     #     admin_storage: &AdminStorage,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     affiliators: vector<address>,
# #     #     nations: vector<String>,
# #     #     ctx: &mut TxContext
# #     # ) {
# # affiliators='["0x1e41203958a8e97930e2a0d5f4de570cbd4d9fb9293b5e2f347662356ec57ea1","0x0078254df53e7d62b05a590f0fbff890213c5a660e1752c4315b513d6186f9b3","0xbb47b7e40f8e1f7f4cd6f15bdeceaccb2afcc103396fc70456dbc2b63f647679","0xd109607b4e1e698b8879ddcbbff0597251f5e70724c96baec12af2da6f321fa4","0x3a6a33bc7d2ebccd33b1dfc0b8a179f1656efe93a00dda91d8237dae30600758","0x87bce7d010ae8a4824ba9bc7445e831afdaaca4c858d610ccd4232bd566fbf66","0x0529e940a97d07c9d78ddba72607012cbff75e3c6d789a7be446e1fa8b760278"]'
# # nations='["AF","CN","VN","KR","VN","JP","FR"]'
# # DATA=`sui client call --package $PACKAGE \
# # --module admin \
# # --function add_affiliator_list \
# # --args $ADMIN_STORAGE $PROJECT $NAME $affiliators $nations \
# # --gas-budget ${GAS_CALL}`
# # echo "Data: ${DATA}"


# # # # # # ================================// REMOVE AFFILIATE //==============================

# #     # public entry fun remove_affiliator_list(
# #     #     admin_storage: &AdminStorage,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     affiliators: vector<address>,
# #     #     nations: vector<String>,
# #     #     ctx: &mut TxContext
# #     # ) {


# # affiliators='["0x1e41203958a8e97930e2a0d5f4de570cbd4d9fb9293b5e2f347662356ec57ea1"]'
# # nations='["VN"]'
# # DATA=`sui client call --package $PACKAGE \
# # --module admin \
# # --function remove_affiliator_list \
# # --args $ADMIN_STORAGE $PROJECT $NAME $affiliators $nations \
# # --gas-budget ${GAS_CALL}`
# # echo "Data: ${DATA}"



# # # ================================// PURCHASE //==============================

# # TOKEN_AMOUNT="16000000000"
# # VEC_PAYMENT='["0x6667eca76b8d0c346f35624475c915b13f2f7223be64a081190b9568c50aeb64"]'

# # # public entry fun purchase<TOKEN, PAYMENT>(clock: &Clock, project: &mut Project, round_name: String, payment: vector<Coin<PAYMENT>>, token_amount: u64, affiliate_code: String, ctx: &mut TxContext) {

# # affiliate_code="CN90213c5a660e1752c4315b513d6186f9b3"
# # DATA=`sui client call --package $PACKAGE \
# # --module launchpad_presale \
# # --function purchase \
# # --type-args $TOKEN_TYPE $PAYMENT_TYPE \
# # --args $CLOCK $PROJECT $NAME $VEC_PAYMENT $TOKEN_AMOUNT $affiliate_code \
# # --gas-budget ${GAS_CALL}`
# # echo "Data: ${DATA}"


# # # # ================================// CLAIM VESTING //==============================

# # PERIOD_ID_LIST='[2,3,4]'

# # DATA=`sui client call --package $PACKAGE \
# # --module launchpad_presale \
# # --function claim_vesting \
# # --type-args $TOKEN_TYPE \
# # --args $CLOCK $PROJECT $NAME $PERIOD_ID_LIST \
# # --gas-budget ${GAS_CALL}`
# # echo "Data: ${DATA}"




# # # ================================// CREATE IDO //==============================

# #     # public entry fun create_round_ido<TOKEN>(
# #     #     admin_storage: &AdminStorage,
# #     #     clock: &Clock,
# #     #     project: &mut Project,
# #     #     name: String,
# #     #     token_decimal: u8,
# #     #     start_at: u64,
# #     #     end_at: u64,
# #     #     max_allocation: u64,
# #     #     min_allocation: u64,
# #     #     min_purchase: u64,
# #     #     total_supply: u64,
# #     #     ctx: &mut TxContext
# #     # ) {

# # TOKEN_DECIMAL="9"
# # START_AT="1685934000000"
# # END_AT="1685955600000"
# # # MIN_ALLOCATION="20000000000"
# # # MAX_ALLOCATION="18446744073709551615"
# # MIN_PURCHASE="10000000000"
# # TOTAL_SUPPLY="3000000000000"

# # DATA=`sui client call --package $PACKAGE \
# # --module admin \
# # --function create_round_ido \
# # --type-args $TOKEN_TYPE \
# # --args $ADMIN_STORAGE $CLOCK $PROJECT $NAME $TOKEN_DECIMAL $START_AT $END_AT $MAX_ALLOCATION $MIN_ALLOCATION $MIN_PURCHASE $TOTAL_SUPPLY \
# # --gas-budget ${GAS_CALL}`
# # echo "Data: ${DATA}"


# # # # # ================================// DEPOSIT BALANCE //==============================


# # COIN="0x2307e13d151c42625d384da5204eb80a6be656f256657290faf266b2a92151b0"
# # # public entry fun deposit_balance<T>(project: &mut Project, round_name: String, coin: Coin<T>, _ctx: &mut TxContext) {
# # DATA=`sui client call --package $PACKAGE \
# # --module launchpad_ido \
# # --function deposit_balance \
# # --type-args $TOKEN_TYPE \
# # --args $PROJECT $NAME $COIN \
# # --gas-budget ${GAS_CALL}`
# # echo "Data: ${DATA}"


# # # # # ================================// PURCHASE //==============================

# # TOKEN_AMOUNT="14000000000"
# # VEC_PAYMENT='["0x73f7e663711480e2cbd1099f0dbc613bd4074c90ac199dc74ddbe9d0e739c636"]'

# # # public entry fun purchase<TOKEN, PAYMENT>(clock: &Clock, project: &mut Project, round_name: String, payment: vector<Coin<PAYMENT>>, token_amount: u64, ctx: &mut TxContext) {

# # DATA=`sui client call --package $PACKAGE \
# # --module launchpad_ido \
# # --function purchase \
# # --type-args $TOKEN_TYPE $PAYMENT_TYPE \
# # --args $CLOCK $PROJECT $NAME $VEC_PAYMENT $TOKEN_AMOUNT \
# # --gas-budget ${GAS_CALL}`
# # echo "Data: ${DATA}"


# # # # # ================================// SET set_start_at //==============================



# #     # public entry fun set_end_at<ROUND>(
# #     #     admin_storage: &AdminStorage,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     new_end_at: u64,
# #     #     ctx: &mut TxContext
# #     # ) {

# # new_start_at="1686072000000"

# # DATA=`sui client call --package $PACKAGE \
# # --module admin \
# # --function set_start_at \
# # --type-args $ROUND \
# # --args $ADMIN_STORAGE $PROJECT $NAME $new_start_at \
# # --gas-budget ${GAS_CALL}`
# # echo "Data: ${DATA}"






# # # # ================================// SET set_max_allocation //==============================


# #     # public entry fun set_max_allocation<ROUND>(
# #     #     admin_storage: &AdminStorage,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     new_max_allocation: u64,
# #     #     ctx: &mut TxContext
# #     # ) {

# # new_max_allocation="60000000000"

# # DATA=`sui client call --package $PACKAGE \
# # --module admin \
# # --function set_max_allocation \
# # --type-args $ROUND \
# # --args $ADMIN_STORAGE $PROJECT $NAME $new_max_allocation \
# # --gas-budget ${GAS_CALL}`
# # echo "Data: ${DATA}"




# # # # # ================================// SET set_is_open_claim_vesting //==============================



# #     # public entry fun set_is_open_claim_vesting<ROUND>(
# #     #     admin_storage: &AdminStorage,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     new_is_open_claim_vesting: bool,
# #     #     ctx: &mut TxContext
# #     # ) {

# # new_is_open_claim_vesting="false"

# # DATA=`sui client call --package $PACKAGE \
# # --module admin \
# # --function set_is_open_claim_vesting \
# # --type-args $ROUND \
# # --args $ADMIN_STORAGE $PROJECT $NAME $new_is_open_claim_vesting \
# # --gas-budget ${GAS_CALL}`
# # echo "Data: ${DATA}"


# # # # # ================================// SET set_is_open_claim_commission //==============================



# #     # public entry fun set_is_open_claim_commission<ROUND>(
# #     #     admin_storage: &AdminStorage,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     new_is_open_claim_commission: bool,
# #     #     ctx: &mut TxContext
# #     # ) {



# # new_is_open_claim_commission="false"

# # DATA=`sui client call --package $PACKAGE \
# # --module admin \
# # --function set_is_open_claim_commission \
# # --type-args $ROUND \
# # --args $ADMIN_STORAGE $PROJECT $NAME $new_is_open_claim_commission \
# # --gas-budget ${GAS_CALL}`
# # echo "Data: ${DATA}"


# # # ================================// CLAIM claim_commission //==============================

# #     # public entry fun claim_commission<T>(
# #     #     clock: &Clock,
# #     #     project: &mut Project,
# #     #     round_name: String,
# #     #     nation: String,
# #     #     ctx: &mut TxContext
# #     # ) {

# # nation="AF"

# # DATA=`sui client call --package $PACKAGE \
# # --module launchpad_presale \
# # --function claim_commission \
# # --type-args $PAYMENT_TYPE \
# # --args $CLOCK $PROJECT $NAME $PERIOD_ID_LIST $nation \
# # --gas-budget ${GAS_CALL}`
# # echo "Data: ${DATA}"



# # # # # ================================// withdraw_balance //==============================



# # # public entry fun withdraw_balance<ROUND, T>(
# # #         admin_storage: &AdminStorage,
# # #         project: &mut Project,
# # #         round_name: String,
# # #         amount: u64,
# # #         ctx: &mut TxContext
# # #     ) {



# # amount="1234"

# # DATA=`sui client call --package $PACKAGE \
# # --module admin \
# # --function withdraw_balance \
# # --type-args $ROUND $PAYMENT_TYPE \
# # --args $ADMIN_STORAGE $PROJECT $NAME $amount \
# # --gas-budget ${GAS_CALL}`
# # echo "Data: ${DATA}"


# # # # # ================================// withdraw_all_balance //==============================

# # DATA=`sui client call --package $PACKAGE \
# # --module admin \
# # --function withdraw_all_balance \
# # --type-args $ROUND $TOKEN_TYPE \
# # --args $ADMIN_STORAGE $PROJECT $NAME \
# # --gas-budget ${GAS_CALL}`
# # echo "Data: ${DATA}"
