{
  config,
  kubenix,
  crds,
  ...
}: {
  imports = with kubenix.modules; [
    submodule
    k8s
    crds
  ];

  kubernetes = {
    namespace = "thenewnorm";

    resources.namespaces.thenewnorm = {};

    resources.serviceAccounts.deploy-service-account = {};

    resources.roles.deployer.rules = [
      {
        apiGroups = ["apps" ""];
        resources = ["deployments" "services" "configmaps" "secrets" "pods"];
        verbs = ["*"];
      }
      {
        apiGroups = ["postgresql.cnpg.io"];
        resources = ["clusters"];
        verbs = ["*"];
      }
      {
        apiGroups = ["cert-vandal.io"];
        resources = ["saninjections"];
        verbs = ["*"];
      }
      {
        apiGroups = ["cert-manager.io"];
        resources = ["certificates"];
        verbs = ["*"];
      }
      {
        apiGroups = ["gateway.networking.k8s.io"];
        resources = ["httproutes" "gateways"];
        verbs = ["*"];
      }
      {
        apiGroups = ["gateway.envoyproxy.io"];
        resources = ["envoyproxies" "clienttrafficpolicies"];
        verbs = ["*"];
      }
      {
        apiGroups = [""];
        resources = ["pods" "pods/log" "pods/status"];
        verbs = ["get" "list" "watch"];
      }
      {
        apiGroups = [""];
        resources = ["pods/exec"];
        verbs = ["create" "get"];
      }
      {
        apiGroups = [""];
        resources = ["pods/portforward"];
        verbs = ["create" "get"];
      }
      {
        apiGroups = ["apps"];
        resources = ["deployments" "deployments/status" "replicasets"];
        verbs = ["get" "list" "watch" "patch"];
      }
      {
        apiGroups = [""];
        resources = ["services" "endpoints"];
        verbs = ["get" "list" "watch"];
      }
      {
        apiGroups = [""];
        resources = ["configmaps"];
        verbs = ["get" "list"];
      }
      {
        apiGroups = [""];
        resources = ["events"];
        verbs = ["get" "list" "watch"];
      }
      {
        apiGroups = ["gateway.networking.k8s.io"];
        resources = ["httproutes" "gateways"];
        verbs = ["get" "list" "watch"];
      }
      {
        apiGroups = ["metrics.k8s.io"];
        resources = ["pods" "nodes"];
        verbs = ["get" "list"];
      }
      {
        apiGroups = ["networking.k8s.io"];
        resources = ["networkpolicies"];
        verbs = ["get" "list" "watch" "create" "update" "patch" "delete"];
      }
    ];

    resources.clusterRoles.gateway-deployer.rules = [
      {
        apiGroups = ["gateway.networking.k8s.io"];
        resources = ["gatewayclasses"];
        verbs = ["*"];
      }
    ];

    resources.clusterRoleBindings.gateway-deployer-binding = {
      subjects = [
        {
          kind = "ServiceAccount";
          name = "deploy-service-account";
          namespace = "thenewnorm";
        }
      ];
      roleRef = {
        kind = "ClusterRole";
        name = "gateway-deployer";
        apiGroup = "rbac.authorization.k8s.io";
      };
    };

    resources.roleBindings.deploy-sa-binding = {
      subjects = [
        {
          kind = "ServiceAccount";
          name = "deploy-service-account";
          namespace = "thenewnorm";
        }
      ];
      roleRef = {
        kind = "Role";
        name = "deployer";
        apiGroup = "rbac.authorization.k8s.io";
      };
    };
  };

  submodule = {
    name = "identities";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
