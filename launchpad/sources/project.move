// SPDX-License-Identifier: Apache-2.0
module yousui::project {
    use sui::transfer;
    use sui::display;
    use sui::package::{Self, Publisher};
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::dynamic_object_field as dof;
    use sui::event::emit;

    use std::string::{String, utf8};

    friend yousui::admin;
    friend yousui::launchpad;
    friend yousui::ido;

    struct ProjectInfo has store, copy, drop {
        project_id: ID,
        name: String,
        twitter: String,
        discord: String,
        telegram: String,
        medium: String,
        website: String,
        image_url: String,
        description: String,
        link_url: String,
    }

    struct Project has key, store {
        id: UID,
        info: ProjectInfo
    }

    struct PROJECT has drop {}

    // ======== Events =========

    struct NewProject has copy, drop {
        project_id: ID,
        project_name: String,
        sender: address
    }

    fun init(witness: PROJECT, ctx: &mut TxContext) {
        let publisher = package::claim(witness, ctx);
        display<Project>(&publisher, ctx);
        transfer::public_transfer(publisher, tx_context::sender(ctx));
    }

    fun display<T: key>(publisher: &Publisher, ctx: &mut TxContext) {
        let keys = vector[
            utf8(b"name"),
            utf8(b"link"),
            utf8(b"image_url"),
            utf8(b"description"),
            utf8(b"project_url"),
            utf8(b"creator"),
        ];
        let values = vector[
            utf8(b"YouSUI x {info.name}"),
            utf8(b"{info.link_url}"),
            utf8(b"{info.image_url}"),
            utf8(b"{info.description}"),
            utf8(b"{info.website}"),
            utf8(b"YouSUI Creator")
        ];
        let display = display::new_with_fields<T>(
            publisher, keys, values, ctx
        );
        display::update_version(&mut display);
        transfer::public_transfer(display, tx_context::sender(ctx));
    }

    public(friend) fun create_project(
        name: String,
        twitter: String,
        discord: String,
        telegram: String,
        medium: String,
        website: String,
        image_url: String,
        description: String,
        link_url: String,
        ctx: &mut TxContext
    ): Project {
        let project_uid = object::new(ctx);
        let project_id = object::uid_to_inner(&project_uid);
        emit(NewProject {
            project_id,
            project_name: name,
            sender: tx_context::sender(ctx)
        });
        Project {
            id: project_uid,
            info: ProjectInfo {
                project_id,
                name,
                twitter,
                discord,
                telegram,
                medium,
                website,
                image_url,
                description,
                link_url,
            }
        }
    }

    public fun get_project_info(project: &Project): ProjectInfo {
        project.info
    }

    public fun get_project_name(project_info: &ProjectInfo): String {
        project_info.name
    }

    public(friend) fun add_dynamic_object_field<T: key + store>(project: &mut Project, field_name: String, filed_value: T) {
        dof::add(&mut project.id, field_name, filed_value);
    }

    public(friend) fun borrow_mut_dynamic_object_field<T: key + store>(project: &mut Project, field_name: String): &mut T {
        dof::borrow_mut(&mut project.id, field_name)
    }

}