# RBAC
 
 RBAC YAML configuration for the `jenkins` ServiceAccount, Role, RoleBinding, ClusterRole, and ClusterRoleBinding to ensure the ServiceAccount can create all the resources in your YAML file, including dynamic provisioning with StorageClasses and PersistentVolumes.




## Explanation of Permissions
1. **ServiceAccount**:  
   - The `jenkins` ServiceAccount is created in the `webapps` namespace.

2. **Role**:
   - Grants access to namespace-specific resources:
     - **Secrets**, **ConfigMaps**, **PersistentVolumeClaims**, **Services**, and **Pods**.
     - **Deployments** and **ReplicaSets** under the `apps` API group.

3. **RoleBinding**:
   - Binds the `jenkins` Role to the ServiceAccount in the `webapps` namespace.

4. **ClusterRole**:
   - Grants access to cluster-wide resources:
     - **PersistentVolumes** (required for dynamic provisioning).
     - **StorageClasses** (required to create and manage storage classes for dynamic PV provisioning).

5. **ClusterRoleBinding**:
   - Binds the `jenkins` ClusterRole to the ServiceAccount for cluster-wide operations.




### How to Apply the YAML Files
1. Save each YAML snippet as a separate file:
   - `serviceaccount.yaml`
   - `role.yaml`
   - `rolebinding.yaml`
   - `clusterrole.yaml`
   - `clusterrolebinding.yaml`

2. Apply them in the following order:
   ```bash
   kubectl apply -f serviceaccount.yaml
   kubectl apply -f role.yaml
   kubectl apply -f rolebinding.yaml
   kubectl apply -f clusterrole.yaml
   kubectl apply -f clusterrolebinding.yaml
   ```

3. Verify the ServiceAccount has the expected permissions:
   ```bash
   kubectl auth can-i create secrets --as=system:serviceaccount:webapps:jenkins -n webapps
   kubectl auth can-i create storageclasses --as=system:serviceaccount:webapps:jenkins
   kubectl auth can-i create persistentvolumes --as=system:serviceaccount:webapps:jenkins
   ```

### Generate token using service account in the namespace
[Create Token](https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/#:~:text=To%20create%20a%20non%2Dexpiring,with%20that%20generated%20token%20data.)



