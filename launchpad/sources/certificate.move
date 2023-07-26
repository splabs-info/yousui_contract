// SPDX-License-Identifier: Apache-2.0
module yousui::certificate {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::display;
    use sui::package;

    use std::string::{String, utf8};

    use yousui::project::{ProjectInfo};

    friend yousui::ido;

    struct InvestmentCertificate has key {
        id: UID,
        project: ProjectInfo,
        event_name: String,
        token_type: String,
        issue_date: u64,
        vesting_id: ID,
        description: String,
    }


    struct CERTIFICATE has drop {}


    fun init(witness: CERTIFICATE, ctx: &mut TxContext) {
        let publisher = package::claim(witness, ctx);

        let keys = vector[
            utf8(b"name"),
            utf8(b"link"),
            utf8(b"image_url"),
            utf8(b"description"),
            utf8(b"project_url"),
            utf8(b"creator"),
        ];
        let values = vector[
            utf8(b"YouSUI x {project.name} <> {event_name} <> Certificate"),
            utf8(b"{project.link_url}"),
            utf8(b"{project.image_url}"),
            utf8(b"{description}"),
            utf8(b"{project.website}"),
            utf8(b"YouSUI Creator")
        ];

        let display = display::new_with_fields<InvestmentCertificate>(&publisher, keys, values, ctx);

        display::update_version(&mut display);
        transfer::public_transfer(display, tx_context::sender(ctx));
        transfer::public_transfer(publisher, tx_context::sender(ctx));
    }

    public(friend) fun issue_investment_certificate(timestamp: u64, project: ProjectInfo, round_name: String, token_type: String, vesting_id: ID, ctx: &mut TxContext) {
        transfer::transfer(
            InvestmentCertificate {
                id: object::new(ctx),
                project,
                event_name: round_name,
                token_type,
                issue_date: timestamp,
                vesting_id,
                description: utf8(b"The investment certificate, published by YouSUI, is a document providing proof of your token investment in a crypto project. It verifies your ownership, including the number of tokens purchased, and grants you certain rights and benefits within the project. The certificate ensures transparency and credibility, protecting your interests and allowing you to participate in project-related decisions. It serves as a valuable record of your investment, issued by YouSUI, in the crypto project.")
            }
            , tx_context::sender(ctx))
    }

    // UPDATE
    public(friend) fun issue_investment_certificate_with_user(timestamp: u64, project: ProjectInfo, round_name: String, token_type: String, vesting_id: ID, user: address, ctx: &mut TxContext) {
        transfer::transfer(
            InvestmentCertificate {
                id: object::new(ctx),
                project,
                event_name: round_name,
                token_type,
                issue_date: timestamp,
                vesting_id,
                description: utf8(b"The investment certificate, published by YouSUI, is a document providing proof of your token investment in a crypto project. It verifies your ownership, including the number of tokens purchased, and grants you certain rights and benefits within the project. The certificate ensures transparency and credibility, protecting your interests and allowing you to participate in project-related decisions. It serves as a valuable record of your investment, issued by YouSUI, in the crypto project.")
            }
            , user)
    }
    // UPDATE
}