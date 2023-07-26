// SPDX-License-Identifier: Apache-2.0
module yousui::service {
    use sui::tx_context::{TxContext};
    use sui::object::{Self, ID, UID};
    use sui::vec_set::{Self, VecSet};
    use sui::dynamic_object_field as dof;
    use sui::object_bag::{Self, ObjectBag};

    use std::string::{String};

    use yousui::utils;

    friend yousui::ido;
    friend yousui::admin;
    
    friend yousui::service_vesting;
    friend yousui::service_affiliate;
    friend yousui::service_preregister;

    const EFeatureAlreadySet: u64 = 600+0;

    struct Service has key, store {
        id: UID,
        features: VecSet<String>,
        other: ObjectBag,
    }


    public(friend) fun new(ctx: &mut TxContext): (Service, ID) {
        let service = Service { id: object::new(ctx), features: vec_set::empty(), other: object_bag::new(ctx)};
        let id = *object::uid_as_inner(uid(&service));
        (service, id)
    }

    public(friend) fun uid(service: &Service): &UID {
        &service.id
    }

    public(friend) fun add_feature<Feature, Config: key + store>(
        service: &mut Service, cfg: Config
    ) {
        let feature_key = utils::get_key_by_struct<Feature>();
        assert!(!has_feature(service, feature_key), EFeatureAlreadySet);
        vec_set::insert(&mut service.features, feature_key);
        dof::add(&mut service.id, feature_key, cfg);
    }

    public(friend) fun remove_feature<Feature, Config: key + store>(
        service: &mut Service
    ): Config {
        let feature_key = utils::get_key_by_struct<Feature>();
        vec_set::remove(&mut service.features, &feature_key);
        dof::remove(&mut service.id, feature_key)
    }

    public(friend) fun get_feature<Feature, Config: key + store>(service: &Service)
    : &Config {
        let feature_key = utils::get_key_by_struct<Feature>();
        dof::borrow(&service.id, feature_key)
    }

    public(friend) fun get_feature_mut<Feature, Config: key + store>(service: &mut Service)
    : &mut Config {
        let feature_key = utils::get_key_by_struct<Feature>();
        dof::borrow_mut(&mut service.id, feature_key)
    }

    public(friend) fun has_feature(service: &Service, feature_key: String): bool {
        vec_set::contains(&service.features, &feature_key)
    }

    public(friend) fun features(self: &Service): &VecSet<String> {
        &self.features
    }
}
