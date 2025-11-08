BEGIN
DBMS_NETWORK_ACL_ADMIN.drop_acl(
    acl => 'smtp_acl.xml'
);
END;
/